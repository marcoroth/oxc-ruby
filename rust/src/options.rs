use std::collections::BTreeMap;
use std::fmt;
use std::marker::PhantomData;
use std::path::PathBuf;

use serde::de::value::MapAccessDeserializer;
use serde::de::{self, MapAccess, Visitor};
use serde::{Deserialize, Deserializer};

use oxc::codegen::{CodegenOptions as OxcCodegenOptions, LegalComment};
use oxc::span::SourceType;
use oxc::str::CompactStr;
use oxc::transformer_plugins::{InjectGlobalVariablesConfig, InjectImport, ReplaceGlobalDefinesConfig};

use oxc::isolated_declarations::IsolatedDeclarationsOptions;
use oxc::transformer::{
  CompilerAssumptions, DecoratorOptions as OxcDecoratorOptions, EngineTargets, EnvOptions, HelperLoaderMode,
  HelperLoaderOptions, JsxOptions as OxcJsxOptions, JsxRuntime, RewriteExtensionsMode,
  TransformOptions as OxcTransformOptions, TypeScriptOptions as OxcTypeScriptOptions,
};

use oxc::minifier::{
  CompressOptions as OxcCompressOptions, CompressOptionsKeepNames, CompressOptionsUnused,
  MangleOptions as OxcMangleOptions, MangleOptionsKeepNames, MinifierOptions, PropertyReadSideEffects,
  TreeShakeOptions as OxcTreeShakeOptions,
};

#[derive(Debug)]
pub enum Toggle<T> {
  Flag(bool),
  Settings(T),
}

impl<'de, T: Deserialize<'de>> Deserialize<'de> for Toggle<T> {
  fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
    deserializer.deserialize_any(ToggleVisitor { marker: PhantomData })
  }
}

struct ToggleVisitor<T> {
  marker: PhantomData<T>,
}

impl<'de, T: Deserialize<'de>> Visitor<'de> for ToggleVisitor<T> {
  type Value = Toggle<T>;

  fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
    formatter.write_str("true, false, or a hash of settings")
  }

  fn visit_bool<E: de::Error>(self, value: bool) -> Result<Self::Value, E> {
    Ok(Toggle::Flag(value))
  }

  fn visit_map<A: MapAccess<'de>>(self, map: A) -> Result<Self::Value, A::Error> {
    T::deserialize(MapAccessDeserializer::new(map)).map(Toggle::Settings)
  }
}

impl<T> Default for Toggle<T> {
  fn default() -> Self {
    Self::Flag(true)
  }
}

impl<T> Toggle<T> {
  pub fn enabled(&self) -> bool {
    !matches!(self, Self::Flag(false))
  }

  pub fn settings(&self) -> Option<&T> {
    match self {
      Self::Settings(settings) => Some(settings),
      Self::Flag(_) => None,
    }
  }
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum Target {
  One(String),
  Many(Vec<String>),
}

impl Target {
  fn to_engine_targets(&self) -> Result<EngineTargets, String> {
    match self {
      Self::One(target) => EngineTargets::from_target(target),
      Self::Many(targets) => EngineTargets::from_target_list(targets),
    }
  }
}

// TODO: add mangle_props. `ManglePropertiesOptions` types `include` and `exclude` as
// `lazy_regex::Regex` and `reserved` as `FxHashSet<CompactStr>`, so it needs `lazy-regex` and
// `rustc-hash` here as direct dependencies, pinned to whatever oxc picked. It also needs the
// `cache` round-trip, since property names are otherwise inconsistent across files.
#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct MinifyOptions {
  pub filename: Option<String>,
  pub lang: Option<String>,
  pub source_type: Option<String>,
  pub compress: Toggle<CompressOptions>,
  pub mangle: Toggle<MangleOptions>,
  pub codegen: Toggle<CodegenOptions>,
  pub sourcemap: bool,
}

impl MinifyOptions {
  pub fn to_minifier_options(&self) -> Result<MinifierOptions, String> {
    self.to_minifier_options_inheriting(None)
  }

  pub fn to_minifier_options_inheriting(&self, inherited: Option<&Target>) -> Result<MinifierOptions, String> {
    let compress = if self.compress.enabled() {
      Some(match self.compress.settings() {
        Some(settings) => settings.to_compress_options(inherited)?,
        None => OxcCompressOptions {
          target: match inherited {
            Some(target) => target.to_engine_targets()?,
            None => OxcCompressOptions::default().target,
          },
          ..OxcCompressOptions::default()
        },
      })
    } else {
      None
    };

    let mangle = if self.mangle.enabled() {
      Some(match self.mangle.settings() {
        Some(settings) => settings.to_mangle_options(),
        None => OxcMangleOptions::default(),
      })
    } else {
      None
    };

    Ok(MinifierOptions {
      compress,
      mangle,
      ..MinifierOptions::default()
    })
  }

  pub fn to_codegen_options(&self) -> Result<OxcCodegenOptions, String> {
    let mut options = match self.codegen.settings() {
      Some(settings) => settings.to_codegen_options()?,
      None => CodegenOptions::whitespace(self.codegen.enabled()),
    };

    if self.sourcemap {
      options.source_map_path = Some(PathBuf::from(self.filename.clone().unwrap_or_default()));
    }

    Ok(options)
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct CompressOptions {
  pub target: Option<Target>,
  pub drop_console: Option<bool>,
  pub drop_debugger: Option<bool>,
  pub unused: Option<Unused>,
  pub keep_names: Option<KeepNames>,
  pub join_vars: Option<bool>,
  pub sequences: Option<bool>,
  pub drop_labels: Option<Vec<String>>,
  pub max_iterations: Option<u8>,
  pub treeshake: Option<TreeShakeOptions>,
}

impl CompressOptions {
  fn to_compress_options(&self, inherited: Option<&Target>) -> Result<OxcCompressOptions, String> {
    let default = OxcCompressOptions::default();

    Ok(OxcCompressOptions {
      target: match self.target.as_ref().or(inherited) {
        Some(target) => target.to_engine_targets()?,
        None => default.target,
      },
      drop_console: self.drop_console.unwrap_or(default.drop_console),
      drop_debugger: self.drop_debugger.unwrap_or(default.drop_debugger),
      join_vars: self.join_vars.unwrap_or(default.join_vars),
      sequences: self.sequences.unwrap_or(default.sequences),
      unused: match &self.unused {
        Some(Unused::Flag(true)) => CompressOptionsUnused::Remove,
        Some(Unused::Flag(false)) => CompressOptionsUnused::Keep,
        Some(Unused::Named(name)) if name == "remove" => CompressOptionsUnused::Remove,
        Some(Unused::Named(name)) if name == "keep" => CompressOptionsUnused::Keep,
        Some(Unused::Named(name)) if name == "keep_assign" => CompressOptionsUnused::KeepAssign,
        Some(Unused::Named(name)) => {
          return Err(format!("Unknown unused: {name}. Expected remove, keep or keep_assign."));
        }
        None => default.unused,
      },
      keep_names: self
        .keep_names
        .as_ref()
        .map(CompressOptionsKeepNames::from)
        .unwrap_or_default(),
      treeshake: match &self.treeshake {
        Some(treeshake) => treeshake.to_treeshake_options()?,
        None => OxcTreeShakeOptions::default(),
      },
      drop_labels: self
        .drop_labels
        .as_ref()
        .map(|labels| labels.iter().cloned().collect())
        .unwrap_or_default(),
      max_iterations: self.max_iterations,
    })
  }
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum Unused {
  Flag(bool),
  Named(String),
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct KeepNames {
  pub function: bool,
  pub class: bool,
}

impl From<&KeepNames> for CompressOptionsKeepNames {
  fn from(names: &KeepNames) -> Self {
    Self {
      function: names.function,
      class: names.class,
    }
  }
}

impl From<&KeepNames> for MangleOptionsKeepNames {
  fn from(names: &KeepNames) -> Self {
    Self {
      function: names.function,
      class: names.class,
    }
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct TreeShakeOptions {
  pub annotations: Option<bool>,
  pub manual_pure_functions: Option<Vec<String>>,
  pub property_read_side_effects: Option<bool>,
  pub property_write_side_effects: Option<bool>,
  pub unknown_global_side_effects: Option<bool>,
  pub invalid_import_side_effects: Option<bool>,
}

impl TreeShakeOptions {
  fn to_treeshake_options(&self) -> Result<OxcTreeShakeOptions, String> {
    let default = OxcTreeShakeOptions::default();

    Ok(OxcTreeShakeOptions {
      annotations: self.annotations.unwrap_or(default.annotations),
      manual_pure_functions: self
        .manual_pure_functions
        .clone()
        .unwrap_or(default.manual_pure_functions),
      property_read_side_effects: match self.property_read_side_effects {
        Some(true) => PropertyReadSideEffects::All,
        Some(false) => PropertyReadSideEffects::None,
        None => default.property_read_side_effects,
      },
      property_write_side_effects: self
        .property_write_side_effects
        .unwrap_or(default.property_write_side_effects),
      unknown_global_side_effects: self
        .unknown_global_side_effects
        .unwrap_or(default.unknown_global_side_effects),
      invalid_import_side_effects: self
        .invalid_import_side_effects
        .unwrap_or(default.invalid_import_side_effects),
    })
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct MangleOptions {
  pub top_level: Option<bool>,
  pub keep_names: Option<Toggle<KeepNames>>,
  pub reserved: Option<Vec<String>>,
  pub debug: Option<bool>,
}

impl MangleOptions {
  fn to_mangle_options(&self) -> OxcMangleOptions {
    let default = OxcMangleOptions::default();

    OxcMangleOptions {
      top_level: self.top_level,
      keep_names: match &self.keep_names {
        Some(Toggle::Flag(false)) => MangleOptionsKeepNames::all_false(),
        Some(Toggle::Flag(true)) => MangleOptionsKeepNames::all_true(),
        Some(Toggle::Settings(names)) => MangleOptionsKeepNames::from(names),
        None => default.keep_names,
      },
      reserved: self.reserved.as_ref().map_or(default.reserved, |names| {
        names.iter().map(|name| CompactStr::from(name.as_str())).collect()
      }),
      debug: self.debug.unwrap_or(default.debug),
    }
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct CodegenOptions {
  pub remove_whitespace: Option<bool>,
  pub legal_comments: Option<LegalComments>,
}

impl CodegenOptions {
  fn whitespace(remove: bool) -> OxcCodegenOptions {
    if remove {
      OxcCodegenOptions::minify()
    } else {
      OxcCodegenOptions {
        minify: false,
        ..OxcCodegenOptions::minify()
      }
    }
  }

  fn to_codegen_options(&self) -> Result<OxcCodegenOptions, String> {
    let mut options = Self::whitespace(self.remove_whitespace.unwrap_or(true));

    if let Some(legal) = &self.legal_comments {
      options.comments.legal = legal.to_legal_comment()?;
    }

    Ok(options)
  }
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum LegalComments {
  Mode(String),
  Linked(LegalCommentsLinked),
}

impl LegalComments {
  fn to_legal_comment(&self) -> Result<LegalComment, String> {
    match self {
      Self::Mode(mode) => match mode.as_str() {
        "none" => Ok(LegalComment::None),
        "inline" => Ok(LegalComment::Inline),
        "eof" => Ok(LegalComment::Eof),
        "external" => Ok(LegalComment::External),
        other => Err(format!(
          "Unknown legal_comments: {other}. Expected none, inline, eof, external or a linked path."
        )),
      },
      Self::Linked(linked) => {
        if linked.linked.is_empty() {
          return Err("legal_comments linked has to be a path.".to_string());
        }

        Ok(LegalComment::Linked(linked.linked.clone()))
      }
    }
  }
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LegalCommentsLinked {
  pub linked: String,
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct TransformOptions {
  pub filename: Option<String>,
  pub lang: Option<String>,
  pub source_type: Option<String>,
  pub cwd: Option<String>,
  pub target: Option<Target>,
  pub jsx: Toggle<JsxOptions>,
  pub typescript: Option<TypeScriptOptions>,
  pub assumptions: Option<Assumptions>,
  pub decorator: Option<DecoratorOptions>,
  pub helpers: Option<Helpers>,
  pub define: Option<BTreeMap<String, String>>,
  pub inject: Option<BTreeMap<String, Injected>>,
  pub minify: Option<Toggle<MinifyOptions>>,
  pub codegen: Option<CodegenOptions>,
  pub sourcemap: bool,
}

impl TransformOptions {
  pub fn to_transform_options(&self) -> Result<OxcTransformOptions, String> {
    let env = match &self.target {
      Some(target) => match target {
        Target::One(target) => EnvOptions::from_target(target)?,
        Target::Many(targets) => EnvOptions::from_target_list(targets)?,
      },
      None => EnvOptions::default(),
    };

    Ok(OxcTransformOptions {
      cwd: self.cwd.clone().map(PathBuf::from).unwrap_or_default(),
      typescript: self
        .typescript
        .as_ref()
        .map(TypeScriptOptions::to_typescript_options)
        .unwrap_or_default(),
      assumptions: self
        .assumptions
        .as_ref()
        .map(Assumptions::to_compiler_assumptions)
        .unwrap_or_default(),
      decorator: self
        .decorator
        .as_ref()
        .map(DecoratorOptions::to_decorator_options)
        .unwrap_or_default(),
      jsx: match (&self.jsx, self.jsx.settings()) {
        (_, Some(settings)) => settings.to_jsx_options(),
        (Toggle::Flag(false), _) => OxcJsxOptions::disable(),
        _ => OxcJsxOptions::enable(),
      },
      env,
      helper_loader: self
        .helpers
        .as_ref()
        .map(Helpers::to_helper_loader_options)
        .transpose()?
        .unwrap_or_default(),
      ..OxcTransformOptions::default()
    })
  }

  pub fn to_isolated_declarations_options(&self) -> Option<IsolatedDeclarationsOptions> {
    let declaration = self
      .typescript
      .as_ref()
      .and_then(|typescript| typescript.declaration.as_ref())?;

    if !declaration.enabled() {
      return None;
    }

    Some(IsolatedDeclarationsOptions {
      strip_internal: declaration.settings().is_some_and(|settings| settings.strip_internal),
    })
  }

  pub fn to_define_config(&self) -> Result<Option<ReplaceGlobalDefinesConfig>, String> {
    let Some(define) = &self.define else {
      return Ok(None);
    };

    let entries = define
      .iter()
      .map(|(name, value)| (name.clone(), value.clone()))
      .collect::<Vec<_>>();

    ReplaceGlobalDefinesConfig::new(&entries)
      .map(Some)
      .map_err(|errors| errors.iter().map(ToString::to_string).collect::<Vec<_>>().join(", "))
  }

  pub fn to_inject_config(&self) -> Result<Option<InjectGlobalVariablesConfig>, String> {
    let Some(inject) = &self.inject else {
      return Ok(None);
    };

    let imports = inject
      .iter()
      .map(|(local, injected)| injected.to_import(local))
      .collect::<Result<Vec<_>, String>>()?;

    Ok(Some(InjectGlobalVariablesConfig::new(imports)))
  }

  pub fn minifying(&self) -> bool {
    self.minify.as_ref().is_some_and(Toggle::enabled)
  }

  pub fn to_minifier_options(&self) -> Result<Option<MinifierOptions>, String> {
    if !self.minifying() {
      return Ok(None);
    }

    let inherited = self.target.as_ref();

    match self.minify.as_ref().and_then(Toggle::settings) {
      Some(settings) => settings.to_minifier_options_inheriting(inherited).map(Some),
      None => Ok(Some(
        MinifyOptions::default().to_minifier_options_inheriting(inherited)?,
      )),
    }
  }

  pub fn to_codegen_options(&self) -> Result<OxcCodegenOptions, String> {
    match &self.codegen {
      Some(codegen) => codegen.to_codegen_options(),
      None => Ok(OxcCodegenOptions {
        minify: self.minifying(),
        ..OxcCodegenOptions::default()
      }),
    }
  }
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum Injected {
  Default(String),
  Named(Vec<String>),
}

impl Injected {
  fn to_import(&self, local: &str) -> Result<InjectImport, String> {
    match self {
      Self::Default(source) => Ok(InjectImport::default_specifier(source, local)),
      Self::Named(parts) => {
        if parts.len() != 2 {
          return Err(format!(
            "inject {local} has to be a source, or a pair of a source and a name."
          ));
        }

        let source = &parts[0];

        Ok(if parts[1] == "*" {
          InjectImport::namespace_specifier(source, local)
        } else {
          InjectImport::named_specifier(source, Some(&parts[1]), local)
        })
      }
    }
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct JsxOptions {
  pub runtime: Option<String>,
  pub development: Option<bool>,
  pub throw_if_namespace: Option<bool>,
  pub pure: Option<bool>,
  pub import_source: Option<String>,
  pub pragma: Option<String>,
  pub pragma_frag: Option<String>,
}

impl JsxOptions {
  fn to_jsx_options(&self) -> OxcJsxOptions {
    let default = OxcJsxOptions::default();

    OxcJsxOptions {
      runtime: match self.runtime.as_deref() {
        Some("classic") => JsxRuntime::Classic,
        _ => JsxRuntime::Automatic,
      },
      development: self.development.unwrap_or(default.development),
      throw_if_namespace: self.throw_if_namespace.unwrap_or(default.throw_if_namespace),
      pure: self.pure.unwrap_or(default.pure),
      import_source: self.import_source.clone(),
      pragma: self.pragma.clone(),
      pragma_frag: self.pragma_frag.clone(),
      ..OxcJsxOptions::default()
    }
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct TypeScriptOptions {
  pub jsx_pragma: Option<String>,
  pub jsx_pragma_frag: Option<String>,
  pub only_remove_type_imports: Option<bool>,
  pub allow_namespaces: Option<bool>,
  pub allow_declare_fields: Option<bool>,
  pub optimize_const_enums: Option<bool>,
  pub optimize_enums: Option<bool>,
  pub remove_class_fields_without_initializer: Option<bool>,
  pub rewrite_import_extensions: Option<String>,
  pub declaration: Option<Toggle<DeclarationOptions>>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct DeclarationOptions {
  pub strip_internal: bool,
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Assumptions {
  pub ignore_function_length: Option<bool>,
  pub no_document_all: Option<bool>,
  pub object_rest_no_symbols: Option<bool>,
  pub pure_getters: Option<bool>,
  pub set_public_class_fields: Option<bool>,
}

impl Assumptions {
  fn to_compiler_assumptions(&self) -> CompilerAssumptions {
    let default = CompilerAssumptions::default();

    CompilerAssumptions {
      ignore_function_length: self.ignore_function_length.unwrap_or(default.ignore_function_length),
      no_document_all: self.no_document_all.unwrap_or(default.no_document_all),
      object_rest_no_symbols: self.object_rest_no_symbols.unwrap_or(default.object_rest_no_symbols),
      pure_getters: self.pure_getters.unwrap_or(default.pure_getters),
      set_public_class_fields: self.set_public_class_fields.unwrap_or(default.set_public_class_fields),
      ..default
    }
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct DecoratorOptions {
  pub legacy: Option<bool>,
  pub emit_decorator_metadata: Option<bool>,
  pub strict_null_checks: Option<bool>,
}

impl DecoratorOptions {
  fn to_decorator_options(&self) -> OxcDecoratorOptions {
    let default = OxcDecoratorOptions::default();

    OxcDecoratorOptions {
      legacy: self.legacy.unwrap_or(default.legacy),
      emit_decorator_metadata: self.emit_decorator_metadata.unwrap_or(default.emit_decorator_metadata),
      strict_null_checks: self.strict_null_checks.unwrap_or(default.strict_null_checks),
    }
  }
}

impl TypeScriptOptions {
  fn to_typescript_options(&self) -> OxcTypeScriptOptions {
    let default = OxcTypeScriptOptions::default();

    OxcTypeScriptOptions {
      jsx_pragma: self.jsx_pragma.clone().map(Into::into).unwrap_or(default.jsx_pragma),
      jsx_pragma_frag: self
        .jsx_pragma_frag
        .clone()
        .map(Into::into)
        .unwrap_or(default.jsx_pragma_frag),
      only_remove_type_imports: self
        .only_remove_type_imports
        .unwrap_or(default.only_remove_type_imports),
      allow_namespaces: self.allow_namespaces.unwrap_or(default.allow_namespaces),
      allow_declare_fields: self.allow_declare_fields.unwrap_or(default.allow_declare_fields),
      optimize_const_enums: self.optimize_const_enums.unwrap_or(default.optimize_const_enums),
      optimize_enums: self.optimize_enums.unwrap_or(default.optimize_enums),
      remove_class_fields_without_initializer: self
        .remove_class_fields_without_initializer
        .unwrap_or(default.remove_class_fields_without_initializer),
      rewrite_import_extensions: match self.rewrite_import_extensions.as_deref() {
        Some("rewrite") => Some(RewriteExtensionsMode::Rewrite),
        Some("remove") => Some(RewriteExtensionsMode::Remove),
        _ => None,
      },
    }
  }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Helpers {
  pub mode: Option<String>,
}

impl Helpers {
  fn to_helper_loader_options(&self) -> Result<HelperLoaderOptions, String> {
    let mode = match self.mode.as_deref() {
      Some("runtime") | None => HelperLoaderMode::Runtime,
      Some("external") => HelperLoaderMode::External,
      Some(other) => return Err(format!("Unknown helpers mode: {other}. Expected runtime or external.")),
    };

    Ok(HelperLoaderOptions {
      mode,
      ..HelperLoaderOptions::default()
    })
  }
}

#[derive(Debug, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ParseOptions {
  pub filename: Option<String>,
  pub lang: Option<String>,
  pub source_type: Option<String>,
  pub ast_type: Option<String>,
  pub ast: bool,
  pub ranges: bool,
  pub preserve_parens: bool,
  pub comments: bool,
  pub module_record: bool,
  pub symbols: bool,
  pub semantic_errors: bool,
}

impl Default for ParseOptions {
  fn default() -> Self {
    Self {
      filename: None,
      lang: None,
      source_type: None,
      ast_type: None,
      ast: true,
      ranges: false,
      preserve_parens: true,
      comments: true,
      module_record: false,
      symbols: false,
      semantic_errors: false,
    }
  }
}

impl ParseOptions {
  pub fn include_ts_fields(&self, source_type: &SourceType) -> Result<bool, String> {
    match self.ast_type.as_deref() {
      Some("js") => Ok(false),
      Some("ts") => Ok(true),
      Some(other) => Err(format!("Unknown ast_type: {other}. Expected js or ts.")),
      None => Ok(!source_type.is_javascript()),
    }
  }
}

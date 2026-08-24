use std::collections::BTreeMap;
use std::ops::ControlFlow;

use oxc::ast::ast::Program;
use oxc::codegen::{CodegenOptions, CodegenReturn};
use oxc::diagnostics::Diagnostics;
use oxc::isolated_declarations::IsolatedDeclarationsOptions;
use oxc::minifier::{CompressOptions, MangleOptions};
use oxc::span::Span;
use oxc::transformer::{TransformOptions as OxcTransformOptions, TransformerReturn};
use oxc::transformer_plugins::{InjectGlobalVariablesConfig, ReplaceGlobalDefinesConfig};
use oxc::CompilerInterface;

use crate::options::TransformOptions;

#[derive(Default)]
pub struct Compiler {
  transform_options: OxcTransformOptions,
  codegen_options: CodegenOptions,
  compress: Option<CompressOptions>,
  mangle: Option<MangleOptions>,
  define: Option<ReplaceGlobalDefinesConfig>,
  inject: Option<InjectGlobalVariablesConfig>,
  sourcemap: bool,
  isolated_declarations: Option<IsolatedDeclarationsOptions>,

  pub code: String,
  pub declaration: Option<String>,
  pub declaration_map: Option<String>,
  pub map: Option<String>,
  pub legal_comments: Vec<Span>,
  pub helpers_used: BTreeMap<String, String>,
  pub errors: Diagnostics,
}

impl Compiler {
  pub fn new(options: &TransformOptions) -> Result<Self, String> {
    let minifier_options = options.to_minifier_options()?;

    Ok(Self {
      transform_options: options.to_transform_options()?,
      codegen_options: options.to_codegen_options()?,
      compress: minifier_options.as_ref().and_then(|options| options.compress.clone()),
      mangle: minifier_options.as_ref().and_then(|options| options.mangle.clone()),
      define: options.to_define_config()?,
      inject: options.to_inject_config()?,
      sourcemap: options.sourcemap,
      isolated_declarations: options.to_isolated_declarations_options(),
      ..Self::default()
    })
  }
}

impl CompilerInterface for Compiler {
  fn handle_errors(&mut self, errors: Diagnostics) {
    self.errors.extend(errors);
  }

  fn enable_sourcemap(&self) -> bool {
    self.sourcemap
  }

  fn transform_options(&self) -> Option<&OxcTransformOptions> {
    Some(&self.transform_options)
  }

  fn isolated_declaration_options(&self) -> Option<IsolatedDeclarationsOptions> {
    self.isolated_declarations
  }

  fn define_options(&self) -> Option<ReplaceGlobalDefinesConfig> {
    self.define.clone()
  }

  fn inject_options(&self) -> Option<InjectGlobalVariablesConfig> {
    self.inject.clone()
  }

  fn compress_options(&self) -> Option<CompressOptions> {
    self.compress.clone()
  }

  fn mangle_options(&self) -> Option<MangleOptions> {
    self.mangle.clone()
  }

  fn codegen_options(&self) -> Option<CodegenOptions> {
    Some(self.codegen_options.clone())
  }

  #[expect(deprecated)]
  fn after_transform(
    &mut self,
    _program: &mut Program<'_>,
    transformer_return: &mut TransformerReturn,
  ) -> ControlFlow<()> {
    self.helpers_used = transformer_return
      .helpers_used
      .drain()
      .map(|(helper, source)| (helper.name().to_string(), source))
      .collect();

    ControlFlow::Continue(())
  }

  fn after_isolated_declarations(&mut self, ret: CodegenReturn<'_>) {
    self.declaration = Some(ret.code);
    self.declaration_map = ret.map.map(|map| map.to_json_string());
  }

  fn after_codegen(&mut self, ret: CodegenReturn<'_>) {
    self.code = ret.code;
    self.map = ret.map.map(|map| map.to_json_string());
    self.legal_comments = ret.legal_comments.iter().map(|comment| comment.span).collect();
  }
}

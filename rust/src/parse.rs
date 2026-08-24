use oxc::allocator::Allocator;
use oxc::ast::CommentKind;
use oxc::parser::{ParseOptions as OxcParseOptions, Parser};
use oxc::semantic::SemanticBuilder;
use serde_json::value::RawValue;

use crate::diagnostic::Diagnostic;
use crate::module_record::ModuleRecord;
use crate::options::ParseOptions;
use crate::result::{Comment, ParsePayload};
use crate::source_type::source_type_for;
use crate::symbols;

pub fn parse_source(source: &str, options: &ParseOptions) -> Result<ParsePayload, String> {
  let filename = options.filename.clone().unwrap_or_default();
  let source_type = source_type_for(&filename, options.lang.as_deref(), options.source_type.as_deref())?;
  let include_ts_fields = options.include_ts_fields(&source_type)?;

  let allocator = Allocator::default();

  let parsed = Parser::new(&allocator, source, source_type)
    .with_options(OxcParseOptions {
      preserve_parens: options.preserve_parens,
      enable_ident_hashes: options.semantic_errors || options.symbols,
      ..OxcParseOptions::default()
    })
    .parse();

  let program = parsed.program;
  let mut diagnostics = parsed.diagnostics;

  let module_record = options.module_record.then(|| ModuleRecord::from(&parsed.module_record));
  let symbols = options.symbols.then(|| symbols::read(&program));

  if options.semantic_errors {
    diagnostics.extend(SemanticBuilder::new_compiler().build(&program).diagnostics);
  }

  let comments = if options.comments {
    collect_comments(source, &program, include_ts_fields)
  } else {
    Vec::new()
  };

  let serialized = if options.ast {
    let json = program.to_estree_json(include_ts_fields, options.ranges);

    Some(RawValue::from_string(json).map_err(|error| format!("Failed to read the AST back: {error}"))?)
  } else {
    None
  };

  Ok(ParsePayload {
    program: serialized,
    module_record,
    symbols,
    comments,
    errors: Diagnostic::from_diagnostics(&filename, source, diagnostics),
    panicked: parsed.panicked,
  })
}

fn collect_comments(source: &str, program: &oxc::ast::ast::Program<'_>, include_ts_fields: bool) -> Vec<Comment> {
  let mut comments = program
    .comments
    .iter()
    .map(|comment| Comment {
      kind: match comment.kind {
        CommentKind::Line => "Line",
        CommentKind::SingleLineBlock | CommentKind::MultiLineBlock => "Block",
      },
      value: comment.content_span().source_text(source).to_string(),
      start: comment.span.start,
      end: comment.span.end,
    })
    .collect::<Vec<_>>();

  if !include_ts_fields {
    if let Some(hashbang) = &program.hashbang {
      comments.insert(
        0,
        Comment {
          kind: "Line",
          value: hashbang.value.to_string(),
          start: hashbang.span.start,
          end: hashbang.span.end,
        },
      );
    }
  }

  comments
}

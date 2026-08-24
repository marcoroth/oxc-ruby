use oxc::span::SourceType;

pub fn source_type_for(filename: &str, lang: Option<&str>, source_type: Option<&str>) -> Result<SourceType, String> {
  let ty = match lang {
    Some("js") => SourceType::unambiguous(),
    Some("jsx") => SourceType::unambiguous().with_jsx(true),
    Some("ts") => SourceType::unambiguous().with_typescript(true),
    Some("tsx") => SourceType::unambiguous().with_typescript(true).with_jsx(true),
    Some("dts") => SourceType::d_ts(),
    Some(other) => return Err(format!("Unknown lang: {other}. Expected js, jsx, ts, tsx or dts.")),
    None => SourceType::from_path(filename).unwrap_or_default(),
  };

  Ok(match source_type {
    Some("script") => ty.with_script(true),
    Some("module") => ty.with_module(true),
    Some("commonjs") => ty.with_commonjs(true),
    Some("unambiguous") => ty.with_unambiguous(true),
    Some(other) => {
      return Err(format!(
        "Unknown source_type: {other}. Expected script, module, commonjs or unambiguous."
      ));
    }
    None => ty,
  })
}

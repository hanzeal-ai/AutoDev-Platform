use crate::protocol;
use crate::store;
use serde_json::Value;

pub(super) fn parse_material_inputs(
    inbound: &protocol::EnvelopeIn,
) -> Result<Vec<store::MaterialInput>, String> {
    let mut material_inputs = Vec::new();
    if let Some(materials) = inbound
        .payload_object()?
        .get("materials")
        .and_then(Value::as_array)
    {
        for item in materials {
            if let Some(path) = item.as_str() {
                material_inputs.push(store::MaterialInput {
                    path: path.to_string(),
                    name: None,
                });
                continue;
            }

            if let Some(obj) = item.as_object() {
                if let Some(path) = obj.get("path").and_then(Value::as_str) {
                    material_inputs.push(store::MaterialInput {
                        path: path.to_string(),
                        name: obj
                            .get("name")
                            .and_then(Value::as_str)
                            .map(ToString::to_string),
                    });
                }
            }
        }
    }

    Ok(material_inputs)
}

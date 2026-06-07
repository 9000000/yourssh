use ironrdp::input::{MouseButton, MousePosition, Operation, Scancode, WheelRotations};
use ironrdp::session::{ActiveStage, ActiveStageOutput};
use ironrdp::session::image::DecodedImage;

use crate::session::SessionCmd;

pub struct InputState {
    db: ironrdp::input::Database,
}

impl InputState {
    pub fn new() -> Self {
        Self { db: ironrdp::input::Database::new() }
    }

    pub fn handle(
        &mut self,
        stage: &mut ActiveStage,
        image: &mut DecodedImage,
        cmd: SessionCmd,
    ) -> anyhow::Result<Vec<ActiveStageOutput>> {
        let ops: Vec<Operation> = match cmd {
            SessionCmd::Mouse { x, y, button, action } => {
                let mut v = vec![Operation::MouseMove(MousePosition { x, y })];
                if let Some(btn) = mouse_button(button) {
                    match action {
                        1 => v.push(Operation::MouseButtonPressed(btn)),
                        2 => v.push(Operation::MouseButtonReleased(btn)),
                        _ => {}
                    }
                }
                v
            }
            SessionCmd::Wheel { delta, horizontal } => {
                vec![Operation::WheelRotations(WheelRotations {
                    is_vertical: !horizontal,
                    rotation_units: delta,
                })]
            }
            SessionCmd::Key { scancode, extended, down } => {
                let sc = Scancode::from_u16(if extended { 0xE000 | scancode } else { scancode });
                vec![if down { Operation::KeyPressed(sc) } else { Operation::KeyReleased(sc) }]
            }
            SessionCmd::ClipboardText(_) | SessionCmd::Disconnect => vec![],
        };
        if ops.is_empty() {
            return Ok(vec![]);
        }
        let events = self.db.apply(ops);
        Ok(stage.process_fastpath_input(image, &events)?)
    }
}

fn mouse_button(code: u8) -> Option<MouseButton> {
    match code {
        1 => Some(MouseButton::Left),
        2 => Some(MouseButton::Right),
        3 => Some(MouseButton::Middle),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::mouse_button;
    use ironrdp::input::MouseButton;

    #[test]
    fn mouse_button_mapping() {
        assert_eq!(mouse_button(1), Some(MouseButton::Left));
        assert_eq!(mouse_button(2), Some(MouseButton::Right));
        assert_eq!(mouse_button(3), Some(MouseButton::Middle));
        assert_eq!(mouse_button(9), None);
    }
}

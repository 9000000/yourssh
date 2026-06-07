use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Mutex;

use tokio::sync::mpsc::UnboundedSender;

/// Commands Dart can push into a running session loop.
pub enum SessionCmd {
    Mouse { x: u16, y: u16, button: u8, action: u8 },
    Wheel { delta: i16, horizontal: bool },
    Key { scancode: u16, extended: bool, down: bool },
    ClipboardText(String),
    Disconnect,
}

static NEXT_ID: AtomicU32 = AtomicU32::new(1);
static SESSIONS: Mutex<Option<HashMap<u32, UnboundedSender<SessionCmd>>>> = Mutex::new(None);

pub mod registry {
    use super::*;

    pub fn insert(tx: UnboundedSender<SessionCmd>) -> u32 {
        let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        SESSIONS.lock().unwrap().get_or_insert_with(HashMap::new).insert(id, tx);
        id
    }

    pub fn send(id: u32, cmd: SessionCmd) -> bool {
        let guard = SESSIONS.lock().unwrap();
        match guard.as_ref().and_then(|m| m.get(&id)) {
            Some(tx) => tx.send(cmd).is_ok(),
            None => false,
        }
    }

    pub fn remove(id: u32) {
        if let Some(m) = SESSIONS.lock().unwrap().as_mut() {
            m.remove(&id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registry_insert_send_remove() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let id = registry::insert(tx);
        assert!(registry::send(id, SessionCmd::Disconnect));
        assert!(matches!(rx.try_recv().unwrap(), SessionCmd::Disconnect));
        registry::remove(id);
        assert!(!registry::send(id, SessionCmd::Disconnect));
    }
}

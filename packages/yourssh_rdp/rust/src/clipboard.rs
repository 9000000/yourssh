use std::sync::{Arc, Mutex};

use ironrdp_cliprdr::backend::CliprdrBackend;
use ironrdp_cliprdr::pdu::{
    ClipboardFormat, ClipboardFormatId, ClipboardGeneralCapabilityFlags, FileContentsRequest,
    FileContentsResponse, FormatDataRequest, FormatDataResponse, LockDataId,
};
use tokio::sync::mpsc::UnboundedSender;

const CF_UNICODETEXT: u32 = 13;

/// Messages sent from the clipboard backend to the session loop.
pub enum CliprdrMsg {
    /// Encode pending text and submit to server as format data.
    SubmitFormatData { data: Vec<u8> },
    /// Ask the server to paste the given format.
    RequestPaste { format_id: u32 },
    /// Text received from the server clipboard.
    RemoteText(String),
    /// Advertise our clipboard format list to the server.
    InitiateCopy(Vec<ClipboardFormat>),
}

/// Shared clipboard state between the session loop and the backend.
#[derive(Default)]
pub struct ClipboardShared {
    /// Text to send when server requests our clipboard content.
    pub pending_text: Option<String>,
}

pub struct SimpleClipboard {
    tx: UnboundedSender<CliprdrMsg>,
    shared: Arc<Mutex<ClipboardShared>>,
}

impl SimpleClipboard {
    pub fn new(
        tx: UnboundedSender<CliprdrMsg>,
        shared: Arc<Mutex<ClipboardShared>>,
    ) -> Self {
        Self { tx, shared }
    }
}

impl std::fmt::Debug for SimpleClipboard {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "SimpleClipboard")
    }
}

ironrdp::core::impl_as_any!(SimpleClipboard);

impl CliprdrBackend for SimpleClipboard {
    fn temporary_directory(&self) -> &str { "" }

    fn client_capabilities(&self) -> ClipboardGeneralCapabilityFlags {
        ClipboardGeneralCapabilityFlags::USE_LONG_FORMAT_NAMES
    }

    fn on_ready(&mut self) {}

    fn on_request_format_list(&mut self) {
        let _ = self.tx.send(CliprdrMsg::InitiateCopy(vec![
            ClipboardFormat::new(ClipboardFormatId::new(CF_UNICODETEXT)),
        ]));
    }

    fn on_process_negotiated_capabilities(&mut self, _: ClipboardGeneralCapabilityFlags) {}

    fn on_format_list_response(&mut self, _ok: bool) {}

    fn on_remote_copy(&mut self, available_formats: &[ClipboardFormat]) {
        if available_formats.iter().any(|f| f.id().value() == CF_UNICODETEXT) {
            let _ = self.tx.send(CliprdrMsg::RequestPaste { format_id: CF_UNICODETEXT });
        }
    }

    fn on_format_data_request(&mut self, _request: FormatDataRequest) {
        let text = self
            .shared
            .lock()
            .unwrap()
            .pending_text
            .clone()
            .unwrap_or_default();
        let _ = self.tx.send(CliprdrMsg::SubmitFormatData { data: text_to_cf_unicode(&text) });
    }

    fn on_format_data_response(&mut self, response: FormatDataResponse<'_>) {
        if response.is_error() {
            return;
        }
        if let Some(text) = cf_unicode_to_text(response.data()) {
            if !text.is_empty() {
                let _ = self.tx.send(CliprdrMsg::RemoteText(text));
            }
        }
    }

    fn on_file_contents_request(&mut self, _: FileContentsRequest) {}
    fn on_file_contents_response(&mut self, _: FileContentsResponse<'_>) {}
    fn on_lock(&mut self, _: LockDataId) {}
    fn on_unlock(&mut self, _: LockDataId) {}
}

/// Encodes UTF-8 text as null-terminated UTF-16LE for CF_UNICODETEXT.
pub fn text_to_cf_unicode(text: &str) -> Vec<u8> {
    text.encode_utf16()
        .flat_map(|c| c.to_le_bytes())
        .chain([0u8, 0u8])
        .collect()
}

/// Decodes null-terminated UTF-16LE bytes (CF_UNICODETEXT) to UTF-8.
pub fn cf_unicode_to_text(data: &[u8]) -> Option<String> {
    if data.len() < 2 {
        return None;
    }
    let utf16: Vec<u16> = data
        .chunks_exact(2)
        .map(|b| u16::from_le_bytes([b[0], b[1]]))
        .take_while(|&c| c != 0)
        .collect();
    String::from_utf16(&utf16).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_cf_unicode() {
        let original = "hello world";
        let encoded = text_to_cf_unicode(original);
        let decoded = cf_unicode_to_text(&encoded).unwrap();
        assert_eq!(decoded, original);
    }

    #[test]
    fn cf_unicode_null_terminated() {
        let encoded = text_to_cf_unicode("hi");
        // "hi" = 2 UTF-16 chars + null = 6 bytes
        assert_eq!(encoded.len(), 6);
        assert_eq!(&encoded[4..], [0, 0]);
    }
}

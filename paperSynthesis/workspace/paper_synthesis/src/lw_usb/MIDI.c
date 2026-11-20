#include <string.h>

#include "project_config.h"
#include "MIDI.h"

#define BUF_BUFFER_SIZE 256
#define USB_CLASS_AUDIO 0x01
#define USB_SUBCLASS_MIDI_STREAMING 0x03

WORD read_word(const BYTE *p) {
    return p[0] | (p[1] << 8);
}

extern DEV_RECORD devtable[];

static BYTE buf[BUF_BUFFER_SIZE];
static EP_RECORD midi_ep[2];

BOOL MIDIProbe(BYTE address, DWORD flags) {
	BYTE rcode;
	BYTE config_value;
	BYTE midi_interface;
	BYTE found_endpoint;
	WORD total_length;
	BYTE* descriptor;
	BYTE* descriptor_end;
	EP_RECORD midi_in_ep = { 0 };

	(void)flags;

	if (address == 0 || address >= USB_NUMDEVICES
			|| devtable[address].epinfo == NULL) {
		return FALSE;
	}

	memset(buf, 0, sizeof(buf));

    // Read JUST configuration descriptor
	rcode = XferGetConfDescr(address, 0, 9, 0, buf);

    // Check that configuration description is correct length and type
	if (rcode != 0 || buf[0] != CONF_DESCR_LEN || buf[1] != USB_DESCRIPTOR_CONFIGURATION) {
		return FALSE;
	}

	total_length = read_word(buf + 2);
    
	if (total_length < buf[0] || total_length > sizeof(buf)) {
		return FALSE;
	}

	memset(buf, 0, sizeof(buf));

    // Read entire configuration descriptor including interface and endpoint descriptors
	rcode = XferGetConfDescr(address, 0, total_length, 0, buf);
	if (rcode != 0
			|| buf[1] != USB_DESCRIPTOR_CONFIGURATION
			|| buf[0] < CONF_DESCR_LEN
			|| buf[0] > total_length) {
		return FALSE;
	}

	config_value = buf[5];
	midi_interface = FALSE;
	found_endpoint = FALSE;
	descriptor = buf + buf[0];
	descriptor_end = buf + total_length;

	while (descriptor < descriptor_end) {
		BYTE descriptor_length;
		WORD remaining;

		remaining = (WORD)(descriptor_end - descriptor);
		if (remaining < 2) {
			return FALSE;
		}

		descriptor_length = descriptor[0];
		if (descriptor_length < 2 || descriptor_length > remaining) {
			return FALSE;
		}

		if (descriptor[1] == USB_DESCRIPTOR_INTERFACE) {
			if (descriptor_length < INTR_DESCR_LEN) {
				return FALSE;
			}
			midi_interface =
					descriptor[3] == 0
					&& descriptor[5] == USB_CLASS_AUDIO
					&& descriptor[6] == USB_SUBCLASS_MIDI_STREAMING;
		} else if (descriptor[1] == USB_DESCRIPTOR_ENDPOINT
				&& midi_interface) {
			BYTE endpoint_address;

			if (descriptor_length < EP_DESCR_LEN) {
				return FALSE;
			}

			endpoint_address = descriptor[2];
			if ((endpoint_address & EP_DIR_IN) != 0
					&& (endpoint_address & 0x0f) != 0
					&& (descriptor[3] & bmUSB_TRANSFER_TYPE)
							== USB_TRANSFER_TYPE_BULK) {
				midi_in_ep.epAddr = endpoint_address;
				midi_in_ep.Attr = descriptor[3];
				midi_in_ep.MaxPktSize = (WORD)descriptor[4]
						| ((WORD)descriptor[5] << 8);
				if (midi_in_ep.MaxPktSize == 0) {
					return FALSE;
				}
				midi_in_ep.Interval = descriptor[6];
				midi_in_ep.sndToggle = bmSNDTOG0;
				midi_in_ep.rcvToggle = bmRCVTOG0;
				found_endpoint = TRUE;
				break;
			}
		}

		descriptor += descriptor_length;
	}

	if (!found_endpoint) {
		return FALSE;
	}

	rcode = XferSetConf(address, 0, config_value);
	if (rcode != 0) {
		return FALSE;
	}

	midi_ep[0] = devtable[address].epinfo[0];
	midi_ep[1] = midi_in_ep;
	devtable[address].epinfo = midi_ep;

	return TRUE;
}

BOOL MIDIEventHandler(BYTE address, BYTE event, void *data, DWORD size) {
	return FALSE;
}

#include <string.h>

#include "project_config.h"
#include "transfer.h"
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

BYTE midi_addr = 0;


BOOL MIDIProbe(BYTE address, DWORD flags) {
	BYTE rcode;
	BYTE config_value;
	BYTE midi_interface;
	BYTE found_endpoint;
	WORD total_length;
	BYTE* descriptor;
	BYTE* descriptor_end;

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
    
	if (total_length > sizeof(buf)) {
		return FALSE;
	}

	memset(buf, 0, sizeof(buf));

    // Read entire configuration descriptor including interface and endpoint descriptors
	rcode = XferGetConfDescr(address, 0, total_length, 0, buf);
	if (rcode != 0 || buf[0] != CONF_DESCR_LEN || buf[1] != USB_DESCRIPTOR_CONFIGURATION) {
		return FALSE;
	}

	config_value = buf[5];
	midi_interface = FALSE;
	found_endpoint = FALSE;
	descriptor = buf + buf[0]; // Pointer to iterate over descriptors
	descriptor_end = buf + total_length; // Pointer to end of entire configuration descriptor

	while (descriptor < descriptor_end) {
		BYTE descriptor_length = descriptor[0];

        // Interface descriptor
		if (descriptor[1] == USB_DESCRIPTOR_INTERFACE) {
			if (descriptor_length < INTR_DESCR_LEN) {
				return FALSE;
			}
			midi_interface =
					descriptor[3] == 0
					&& descriptor[5] == USB_CLASS_AUDIO
					&& descriptor[6] == USB_SUBCLASS_MIDI_STREAMING;

            midi_addr = address;
            devtable[address].devclass = MIDI_DRIVER;                  //device class

        // Endpoint descriptor
		} else if (descriptor[1] == USB_DESCRIPTOR_ENDPOINT && midi_interface) {
			BYTE endpoint_address;

			if (descriptor_length < EP_DESCR_LEN) {
				return FALSE;
			}

			endpoint_address = descriptor[2];
            // Check for IN, non-zero address, bulk transfer
			if ((endpoint_address & EP_DIR_IN) != 0
					&& (endpoint_address & 0x0f) != 0
					&& (descriptor[3] & bmUSB_TRANSFER_TYPE)
							== USB_TRANSFER_TYPE_BULK) {

				midi_ep[1].epAddr = endpoint_address;
				midi_ep[1].Attr = descriptor[3];
				midi_ep[1].MaxPktSize = read_word(descriptor + 4);
                
				if (midi_ep[1].MaxPktSize == 0) {
					return FALSE;
				}
				midi_ep[1].Interval = descriptor[6];
				midi_ep[1].sndToggle = bmSNDTOG0;
				midi_ep[1].rcvToggle = bmRCVTOG0;
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

    // Copy over control endpoint including MaxPktSize
	midi_ep[0] = devtable[address].epinfo[0];
	devtable[address].epinfo = midi_ep;

	return TRUE;
}

BYTE MIDIPoll(void* buf) {
    BYTE rcode;
	MAXreg_wr( rPERADDR, midi_addr);    //set peripheral address
	rcode = XferInTransfer(midi_addr, 1, 8, (BYTE*) buf,
			devtable[midi_addr].epinfo[1].MaxPktSize);
	return (rcode);
}

BOOL MIDIEventHandler(BYTE address, BYTE event, void *data, DWORD size) {
	return FALSE;
}

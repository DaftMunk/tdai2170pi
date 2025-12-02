# TDAI2170pi
Lyngdorf TDAI-2170 serial control for Raspberry Pi. 
The system is intended to run headless, but is left open for you to install other relevant software such as raspotify.

This package has been generated to enable access to your favorite amp, the Lyngdorf TDAI-2170,
from the new Lyngdorf phone / tablet app. 

The Raspberry Pi will act as a serial server (reverse telnet), with your phone connecting to the server, the Pi will route commands to the serial port that in turn will control the TDAI-2170.

For simplicity this setup assumes that a USB to serial dongle is available, as well as a TDAI2170 specific DB9 to RJ12 cable. 

## Installation

Installation currently requires some knowledge about Linux and rpi, i.e. you need to be able to SSH into your Pi and execute simple commands.
Connect your USB to DB9 accessory to the rpi prior to executing the following install script:

```sh
sudo apt-get -y install curl && curl -sL https://raw.githubusercontent.com/DaftMunk/tdai2170pi/main/install.sh | sh
```

## Hardware

It is recommended to use an FTDI (the chip make) based USB-A to DB9 cable as these chips work well with Linux and the rpi (I used a Nördic USB-A to RS232 cable).

The TDAI-2170 has a RS232 input in the form of a RJ12 port, as such an extra cable is required (DB9 to RJ12).
This can be ordered through your Lyngdorf dealer at a very fair price, part number: 506005100.

Note, unfortunately the TDAI-2170 RS232 input uses non-standard cabling (not simple UART) Pin4 = GND, Pin5 = Rx, Pin6 = Tx.

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ Raspberry Pi    │ ---> │  USB to DB9     │ ---> │  DB9 to RJ12    │ ---> │   TDAI-2170     │
│      USB        │      │     Cable       │      │     Cable       │      │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘      └─────────────────┘
```

## Software

The serial port (4001) settings are always 8 data bits, no parity and one stop bit with a baud rate of 115200.

The serial service will be restarted automatically upon reboot of the rpi.

To connect the phone app to the rpi and amp, cable the system up as shown above, install the software, in the app add the device manually.

## Disclaimer

This project is provided "AS IS" without warranty of any kind. 
The author is not responsible for any damage to your Raspberry Pi, SD card, hardware, amplifier or any other loss/damage that may occur from using this code.
Use at your own risk.

## License

This project is licensed under the MIT License - see the [`LICENSE`](LICENSE) file for details.

## References

- [Lyngdorf TDAI-2170 Moxa Setup Guide](https://lyngdorf.steinwaylyngdorf.com/downloads/lyngdorf-tdai-2170-moxa-setup-guide/) - Official setup guide for remote app connectivity
- [Lyngdorf TDAI-2170 External Control Manual](https://lyngdorf.steinwaylyngdorf.com/downloads/lyngdorf-tdai-2170-external-control-manual/) - Serial communication protocol and command reference

# koheron-sdk

[![Circle CI](https://circleci.com/gh/Koheron/koheron-sdk.svg?style=shield)](https://circleci.com/gh/Koheron/koheron-sdk)

## What is Koheron SDK ?

Koheron SDK is a build system for quick prototyping of custom instruments on Zynq SoCs.

## Quickstart with the [Red Pitaya](http://redpitaya.com)

### 1. Requirements for Ubuntu 16.04

#### 1.1. Download [`Vivado HLx 2016.3: All OS Installer Single-File Download`](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2016-3.html).

#### 1.2 Run

```bash
$ sudo apt-get install curl
$ cd ~/Downloads
$ curl https://raw.githubusercontent.com/Koheron/koheron-sdk/master/fpga/scripts/install_vivado.sh | sudo /bin/bash /dev/stdin
$ sudo ln -s make /usr/bin/gmake # tells Vivado to use make instead of gmake
```

#### 1.3. Install requirements

```bash
$ sudo apt-get install git curl zip python-virtualenv python-pip \
    g++-arm-linux-gnueabihf lib32stdc++6 lib32z1 u-boot-tools \
    libssl-dev bc device-tree-compiler qemu-user-static
$ sudo apt-get install git
$ git clone https://github.com/Koheron/koheron-sdk
$ cd koheron-sdk
$ sudo pip install -r requirements.txt
```

### 2. Install Koheron Linux for Red Pitaya ([Download SD card image](https://github.com/Koheron/koheron-sdk/releases))

### 3. Build and run the minimal instrument

```bash
$ source settings.sh
$ make NAME=led_blinker HOST=192.168.1.100 run
```
where `HOST` is your Red Pitaya IP address.

### 4. Ping the board and watch the LEDs blink

```bash
$ curl http://$(HOST)/api/board/ping
```

## Examples of instruments

* [`led_blinker`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/led_blinker) : minimal instrument with LED control from Python.
* [`adc_dac`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/adc_dac) : instrument with minimal read/write capability on Red Pitaya ADCs and DACs.
* [`pulse_generator`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/pulse_generator) : pulse generation with synchronous acquisition.
* [`laser_controller`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/decimator) : laser current control using pulse-density modulation.
* [`decimator`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/decimator) : decimation using a compensated CIC filter.
* [`oscillo`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/oscillo) : signal acquisition / generation with coherent averaging mode.
* [`spectrum`](https://github.com/Koheron/koheron-sdk/tree/master/instruments/spectrum) : spectrum analyzer with peak-detection and averaging.

## How to

Open Vivado and build the instrument block design:
```
$ make NAME=oscillo bd
```

Build the SD card image:
```
$ make NAME=led_blinker linux
$ sudo bash os/scripts/image.sh led_blinker
```

Build the instrument (without running it):
```
$ make NAME=oscillo
```

Test a verilog core:
```
$ make CORE=comparator_v1_0 test_core
```

Test a Tcl module:
```
$ make NAME=averager INSTRUMENT_PATH=fpga/modules test_module
```



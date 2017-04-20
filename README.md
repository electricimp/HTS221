# Driver for the HTS221 Temperature Humidity Sensor

The [HTS221](http://www.st.com/content/ccc/resource/technical/document/datasheet/4d/9a/9c/ad/25/07/42/34/DM00116291.pdf/files/DM00116291.pdf/jcr:content/translations/en.DM00116291.pdf) is an ultra-compact sensor for relative humidity and temperature.

The HTS221 can interface over I&sup2;C or SPI. This class addresses only I&sup2;C for the time being.

**To add this library to your project, add** `#require "HTS221.device.lib.nut:2.0.0"` **to the top of your device code**

## Release Notes

| Version | Description |
| --- | --- |
| 1.0.0 | Initial release |
| 1.0.1 | Fix timing in *read()* when run asynchronously; correctly structure table returned by *read()*; code tidy |
| 2.0.0 | Fix bug in *configureDataReadyInterrupt()*; added tests; renamed library file to match new naming conventions |

[![Build Status](https://api.travis-ci.org/electricimp/HTS221.svg?branch=master)](https://travis-ci.org/electricimp/HTS221)

## Class Usage

### Constructor: HTS221(*impI2cBus[, i2cAddress]*)

The constructor takes two arguments to instantiate the class: a *pre-configured* I&sup2;C bus and the sensor’s I&sup2;C address in 8-bit form. The I&sup2;C address is optional and defaults to `0xBE`.

```squirrel
#require "HTS221.device.lib.nut:2.0.0"

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tempHumid <- HTS221(hardware.i2c89);
```

## Class Methods

### setMode(*mode[, dataRate]*)

The HTS221 can be configured in three different reading modes: *HTS221_MODE.POWER_DOWN*, *HTS221_MODE.ONE_SHOT* or *HTS221_MODE.CONTINUOUS*.

*HTS221_MODE.POWER_DOWN* is the default mode; no readings can be taken in this mode. In *HTS221_MODE.ONE_SHOT*, a reading will only be taken only when the *read()* method is called. In *HTS221_MODE.CONTINUOUS*, a reading frequency must also be selected using the *dataRate* parameter. Readings will be taken continuously at the selected rate and when the *read()* method is called only the latest reading will be returned.

The *dataRate* parameter sets the output data rate (ODR) of the sensor in Hertz. The nearest supported ODR less than or equal to the requested rate will be set and returned by *setMode()*. Supported data rates are 0 (one-shot configuration), 1, 7 and 12.5Hz.

```squirrel
// Configure sensor in one shot mode
tempHumid.setMode(HTS221_MODE.ONE_SHOT);
```

```squirrel
// Configure sensor in continuous mode
local dataRate = tempHumid.setMode(HTS221_MODE.CONTINUOUS, 7);
server.log(dataRate);
```

### getMode()

Returns the pressure sensor’s current mode: *HTS221_MODE.POWER_DOWN*, *HTS221_MODE.ONE_SHOT* or *HTS221_MODE.CONTINUOUS*.

```squirrel
local mode = tempHumid.getMode();
if (mode == HTS221_MODE.ONE_SHOT) {
    server.log("In one shot mode");
}

if (mode == HTS221_MODE.CONTINUOUS) {
    server.log("In continuous mode with a data rate of " + tempHumid.getDataRate() + "Hz");
}

if (mode == HTS221_MODE.POWER_DOWN) {
    server.log("In power down mode");
}
```

### getDataRate()

Returns the output data rate (ODR) of the pressure sensor in Hertz.

```squirrel
local dataRate = tempHumid.getDataRate();
server.log(dataRate);
```

### read(*[callback]*)

The *read()* method returns a relative humidity reading and a temperature reading in degrees Celsius. The reading result is in the form of a table with the fields *humidity* and *temperature*. If an error occurs during the reading process, the *humidity* and *temperature* fields will be null. Instead the table will contain the field *error*, which holds a description of the error.

If a callback function is provided, the reading executes asynchronously, and the results table will be passed to the supplied function as its only parameter. If no callback is provided, the method blocks until the reading has been taken and then returns the results table.

#### Asynchronous Example

```squirrel
tempHumid.read(function(result) {
    if ("error" in result) {
        server.error("An Error Occurred: " + result.error);
    } else {
        server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
    }
});
```

#### Synchronous Example

```squirrel
local result = tempHumid.read();

if ("error" in result) {
    server.error("An Error Occurred: " + result.error);
} else {
    server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
}
```

### setResolution(*numTempSamples, numHumidSamples*)

The *setResolution()* method sets the sensor’s temperature and humidity resolution mode and takes two required parameters: an integer *numTempSamples* which is the number of averaged temperature samples, and an integer *numHumidSamples*, the number of averaged humidity samples. The nearest supported sample rate less than or equal to the requested will be set. The actual temperature and humidity sample rates will be returned in a table with the keys *temperatureResolution* and *humidityResolution*.

Supported temperature sample rates are 2, 4, 8, 16, 32, 64, 128 and 256.

Supported humidity sample rates are 4, 8, 16, 32, 64, 128, 256 and 512.

```squirrel
tempHumid.setResolution(8, 16);
```

### getResolution(*mode, enabled*)

The *getResolution()* method gets the current sample rates for temperature and humidity. The method returns a table with the keys *temperatureResolution* and *humidityResolution*.

```squirrel
local res = tempHumid.getResolution();
server.log("Number of temperature samples: " + res.temperatureResolution);
server.log("Number of humidity samples: " + res.humidityResolution);
```

### configureDataReadyInterrupt(*enable[, options]*)

This method configures the interrupt pin driver for a data ready interrupt. The device starts with this disabled by default.

#### Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| *enable* | Boolean | N/A | Set `true` to enable the interrupt pin |
| *options* | Bitfield | 0x00 | Configuration options combined with the bitwise OR operator. See the ‘Options’ table below |

#### Options

| Option Constant | Description |
| --- | --- |
| *INT_PIN_ACTIVELOW* | Interrupt pin is active-high by default. Use to set interrupt to active-low |
| *INT_PIN_OPENDRAIN* | Interrupt pin driver push-pull by default. Use to set interrupt to open-drain |

```squirrel
// Enable interrupt, configure as push-pull, active-high.
tempHumid.configureDataReadyInterrupt(true);
```

```squirrel
// Enable interrupt, configure as open drain, active-low.
tempHumid.configureDataReadyInterrupt(true, HTS221.INT_PIN_ACTIVELOW | HTS221.INT_PIN_OPENDRAIN);
```

### getInterruptStatus()

Use the *getInterruptStatus()* method to determine what caused an interrupt. This method returns a table with two keys to provide information about which interrupts are active. The content of this table is updated every one-shot reading, and after completion of every ODR cycle.

| Key | Description |
| --- | --- |
| *humidity_data_available* | `true` if new humidity data is available |
| *temp_data_available* | `true` if new humidity data is available |

```squirrel
// Check the interrupt source and clear the latched interrupt
local intSrc = tempHumid.getInterruptStatus();

// Log if new data is available
if (intSrc.humidity_data_available) server.log("New humidity data available");
if (intSrc.temp_data_available) server.log("New temperature data available");

```

### getDeviceID()

Returns the value of the sensor’s device ID register, `0xBC`.

## License

The HTS221 library is licensed under the [MIT License](./LICENSE).

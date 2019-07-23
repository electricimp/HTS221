# HTS221 2.0.2 #

This library provides a driver for the [ST Micro HTS221](http://www.st.com/content/ccc/resource/technical/document/datasheet/4d/9a/9c/ad/25/07/42/34/DM00116291.pdf/files/DM00116291.pdf/jcr:content/translations/en.DM00116291.pdf), an ultra-compact sensor for relative humidity and temperature.

The HTS221 can interface over I&sup2;C or SPI. This library current addresses only I&sup2;C communications.

**To include this library in your project, add** `#require "HTS221.device.lib.nut:2.0.2"` **at the top of your device code**

![Build Status](https://cse-ci.electricimp.com/app/rest/builds/buildType:(id:Hts221_BuildAndTest)/statusIcon)

## Class Usage ##

### Constructor: HTS221(*impI2cBus[, i2cAddress]*) ###

The constructor requires two entities to instantiate the class: an imp I&sup2;C bus object and the sensor’s I&sup2;C address in 8-bit form. The I&sup2;C bus must be already configured. The I&sup2;C address is optional.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *impI2cBus* | Object | Yes | An imp I&sup2;C bus object. It must be configured before passing into the constructor |
| *i2cAddress* | Integer | No | The sensor’s I&sup2;C address in 8-bit form. Default: `0xBE` |

#### Example ####

```squirrel
#require "HTS221.device.lib.nut:2.0.2"

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
tempHumid <- HTS221(hardware.i2c89);
```

## Class Methods ##

### setMode(*mode[, dataRate]*) ###

The HTS221 can be configured in three different reading modes:

- *HTS221_MODE.POWER_DOWN* &mdash; The default mode; no readings can be taken in this mode.
- *HTS221_MODE.ONE_SHOT* &mdash; In this mode, a reading will only be taken only when the [*read()*](#readcallback) method is called.
- *HTS221_MODE.CONTINUOUS* &mdash; In this mode, readings will be taken continuously at a selected rate, so a reading frequency, aka output data rate (ODR), must also be selected (using the method’s *dataRate* parameter). When [*read()*](#readcallback) is called only the latest reading will be returned.

This method applies the mode you have chosen.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *mode* | Integer | Yes | One of the following mode constants: *HTS221_MODE.POWER_DOWN*, *HTS221_MODE.ONE_SHOT* or *HTS221_MODE.CONTINUOUS* |
| *dataRate* | Integer | No | The requested output data rate (ODR) of the sensor in Hertz. Supported data rates are 0 (one-shot configuration), 1, 7 and 12.5Hz. Only required when *HTS221_MODE.CONTINUOUS* is selected. Default: 0 |

#### Return Value ####

Integer &mdash; The applied ODR in Hertz.

#### Examples ####

```squirrel
// Configure sensor in one shot mode
tempHumid.setMode(HTS221_MODE.ONE_SHOT);
```

```squirrel
// Configure sensor in continuous mode
local dataRate = tempHumid.setMode(HTS221_MODE.CONTINUOUS, 7);
server.log(dataRate);
```

### getMode() ###

This method indicates which mode the sensor has been set to: *HTS221_MODE.POWER_DOWN*, *HTS221_MODE.ONE_SHOT* or *HTS221_MODE.CONTINUOUS*.

#### Return Value ####

Integer &mdash; The sensor’s current mode.

#### Example ####

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

### getDataRate() ###

This method indicates the sensor’s current output data rate (ODR) in Hertz.

#### Return Value ####

Integer &mdash; The sensor’s current ODR.

#### Example ####

```squirrel
local dataRate = tempHumid.getDataRate();
server.log(dataRate);
```

### setResolution(*numTempSamples, numHumidSamples*) ###

This method sets the sensor’s temperature and humidity resolution in terms of the number of samples of each value that are taken and then averaged when a reading is requested.

Setting each resolution is a request: the actual values applied are returned by the method.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *numTempSamples* | Integer | Yes | The number of averaged temperature samples. Supported temperature sample rates are 2, 4, 8, 16, 32, 64, 128 and 256 |
| *numHumidSamples* | Integer | Yes | The number of averaged humidity samples. Supported humidity sample rates are 4, 8, 16, 32, 64, 128, 256 and 512 |

#### Return Value ####

Table &mdash; the applied resolutions, accessed via the keys *temperatureResolution* and *humidityResolution*.

#### Example ####

```squirrel
tempHumid.setResolution(8, 16);
```

### getResolution() ###

This method retrieves the sensor’s current temperature and humidity resolution in terms of the number of samples of each value that are taken and then averaged when a reading is requested.

#### Return Value ####

Table &mdash; the applied resolutions, accessed via the keys *temperatureResolution* and *humidityResolution*.

#### Example ####

```squirrel
local res = tempHumid.getResolution();
server.log("Number of temperature samples: " + res.temperatureResolution);
server.log("   Number of humidity samples: " + res.humidityResolution);
```

### configureDataReadyInterrupt(*enable[, options]*)

This method configures the interrupt pin driver for a data-ready interrupt. The device starts with this disabled by default.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *enable* | Boolean | Yes | Set `true` to enable the interrupt pin, or `false` to disable it again |
| *options* | Bitfield | No | Configuration options combined with the bitwise OR operator. See [**Options**](#options), below, for available values. Default: `0x00` |

#### Options ####

| Option Constant | Description |
| --- | --- |
| *HTS221_INT_PIN_ACTIVELOW* | Interrupt pin is active-high by default. Use to set interrupt to active-low |
| *HTS221_INT_PIN_OPENDRAIN* | Interrupt pin driver push-pull by default. Use to set interrupt to open-drain |

#### Return Value ####

Nothing.

#### Examples ####

```squirrel
// Enable interrupt, configure as push-pull, active-high.
tempHumid.configureDataReadyInterrupt(true);
```

```squirrel
// Enable interrupt, configure as open drain, active-low.
tempHumid.configureDataReadyInterrupt(true, HTS221_INT_PIN_ACTIVELOW | HTS221_INT_PIN_OPENDRAIN);
```

### getInterruptStatus() ###

Use this method to determine what caused an interrupt: it returns a table that provides information about which interrupts are active. The content of this table is updated every one-shot reading, and after completion of every ODR cycle.

#### Return Value ####

Table &mdash; Interrupt information via the following keys:

| Key | Description |
| --- | --- |
| *humidity_data_available* | `true` if new humidity data is available |
| *temp_data_available* | `true` if new humidity data is available |

#### Example ####

```squirrel
// Check the interrupt source and clear the latched interrupt
local intSrc = tempHumid.getInterruptStatus();

// Log if new data is available
if (intSrc.humidity_data_available) server.log("New humidity data available");
if (intSrc.temp_data_available) server.log("New temperature data available");
```

### read(*[callback]*) ###

This method executes a temperature and humidity reading operation. If a callback function is provided, the reading executes asynchronously and a results table is passed to the callback, otherwise the reading blocks until completed and the results table is returned.

The results table will contain either an *error* slot, which holds a description of the error if an error occurred during the reading process, or *humidity* and *temperature* slots, which contain the relative humidity and temperature in degrees Celsius if the reading was successful.

#### Parameters ####

| Parameter | Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | No | A function that will be called when the reading has been taken. It is passed a reading results table (see above) |

#### Return Value ####

Table &mdash; the reading result table (see above), or `null` if the result is to be delivered asynchronously.

#### Asynchronous Example ####

```squirrel
tempHumid.read(function(result) {
    if ("error" in result) {
        server.error("An Error Occurred: " + result.error);
    } else {
        server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
    }
});
```

#### Synchronous Example ####

```squirrel
local result = tempHumid.read();

if ("error" in result) {
    server.error("An Error Occurred: " + result.error);
} else {
    server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
}
```

### getDeviceID() ###

This method provides you with the value of the sensor’s device ID register. This will be `0xBC` for the HTS221.

#### Return Value ####

Integer &mdash; The sensor’s device ID.

## Release Notes ##

| Version | Description |
| --- | --- |
| 1.0.0 | Initial release |
| 1.0.1 | Fix timing in [*read()*](#readcallback) when run asynchronously; correctly structure table returned by [*read()*](#readcallback) |
| 2.0.0 | Fix bug in [*configureDataReadyInterrupt()*](#configuredatareadyinterruptenable-options); added tests; renamed library file to match new naming conventions |
| 2.0.1 | Force reset before reading call; more elegant sign extension |
| 2.0.2 | Limit humidity readings to values between 0-100; fixed bug in [*read()*](#readcallback) one shot mode; moved static variables to constants |

## License ##

This library is licensed under the [MIT License](./LICENSE).

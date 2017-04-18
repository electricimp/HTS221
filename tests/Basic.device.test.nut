// Copyright 2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


// Tests written for an Imp 001 Explorer kit

class BasicTestCase extends ImpTestCase {

    _tempHumid = null;
    _int = null;

    // Initialize sensor
    function setUp() {
        local _i2c = hardware.i2c89;
        _i2c.configure(CLOCK_SPEED_400_KHZ);

        _tempHumid = HTS221(_i2c, 0xBE);

        return "Sensor initialized";
    }

    function testSensorDevID() {
        local id = _tempHumid.getDeviceID();
        this.assertEqual(0xBC, id, "Device id doesn't match datasheet");
    }

    // Test mode
    function testSetGetMode() {
        local dataRate = _tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        this.assertEqual(0, dataRate, "Set mode return value not equal to expected data rate");
        local mode = _tempHumid.getMode();
        this.assertEqual(HTS221_MODE.ONE_SHOT, mode, "Get mode return value not equal to expected data rate");
    }

    function testSyncRead() {
        _tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        local result = _tempHumid.read();
        this.info(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
        this.assertTrue(result.temperature > 0 && result.temperature < 50, "Temperature reading not within acceptable bounds");
        this.assertTrue(result.humidity > 0 && result.humidity < 100, "Humidity reading not within acceptable bounds");
    }

    function testAsyncRead() {
        _tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        return Promise(function(resolve, reject) {
            _tempHumid.read(function(result) {
                if ("error" in result) {
                    reject(result.error);
                } else {
                    this.info(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", result.humidity, "%", result.temperature));
                    this.assertTrue(result.temperature > 0 && result.temperature < 50, "Temperature not within acceptable bounds");
                    this.assertTrue(result.humidity > 0 && result.humidity < 100, "Humidity reading not within acceptable bounds");
                    resolve();
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function testSetGetSupportedResolution() {
        local res1 = _tempHumid.setResolution(16, 32);
        this.assertEqual(16, res1.temperatureResolution, "Set temperature resolution not equal to expected value");
        this.assertEqual(32, res1.humidityResolution, "Set humidity resolution not equal to expected value");
        local res2 = _tempHumid.getResolution();
        this.assertEqual(16, res2.temperatureResolution, "Get temperature resolution not equal to expected value");
        this.assertEqual(32, res2.humidityResolution, "Get humidity resolution not equal to expected value");
    }

    function testSetGetUnsupportedResolution() {
        local res1 = _tempHumid.setResolution(12, 20);
        this.assertEqual(8, res1.temperatureResolution, "Set temperature resolution not equal to expected adjusted value");
        this.assertEqual(16, res1.humidityResolution, "Set humidity resolution not equal to expected adjusted value");
        local res2 = _tempHumid.getResolution();
        this.assertEqual(8, res2.temperatureResolution, "Get temperature resolution not equal to expected adjusted value");
        this.assertEqual(16, res2.humidityResolution, "Get humidity resolution not equal to expected adjusted value");
    }

    function testInterrupt() {
        _int = hardware.pin1;
        _int.configure(DIGITAL_IN_WAKEUP, function() {
            if (_int.read() == 0) return;
            local result = _tempHumid.getInterruptStatus();
            this.info("New humidity data available: " + result.humidity_data_available);
            this.info("New temperature data available: " + result.temp_data_available);
            this.assertTrue(result.humidity_data_available || result.temp_data_available, "Data ready interrupt not triggerd as expected");
        }.bindenv(this))
        _tempHumid.setMode(HTS221_MODE.CONTINUOUS, 1);
        _tempHumid.getInterruptStatus();
        _tempHumid.configureDataReadyInterrupt(true);
    }

    function tearDown() {
        _tempHumid.configureDataReadyInterrupt(false);
        _tempHumid.setMode(HTS221_MODE.POWER_DOWN);
    }

}

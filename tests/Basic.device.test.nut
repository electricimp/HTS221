// Copyright 2017-19 Electric Imp
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
    _i2c = null;

    // Initialize sensor
    function setUp() {
        _i2c = hardware.i2c89;
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
        return Promise(function(resolve, reject) {
            // Configure interrupt callback
            _int.configure(DIGITAL_IN_WAKEUP, function() {
                if (_int.read() != 0) {
                    local result = _tempHumid.getInterruptStatus();
                    this.info("New humidity data available: " + result.humidity_data_available);
                    this.info("New temperature data available: " + result.temp_data_available);
                    this.assertTrue(result.humidity_data_available || result.temp_data_available, "Data ready interrupt not triggerd as expected");
                    _tempHumid.configureDataReadyInterrupt(false);
                    // Clear the Data interrupt table
                    _tempHumid.read();
                    // Shut down sensor
                    _tempHumid.setMode(HTS221_MODE.POWER_DOWN);
                    // // Debug Logs to confirm interrupt is cleared
                    // info(_int.read());
                    // local result = _tempHumid.getInterruptStatus();
                    // this.info("New humidity data available: " + result.humidity_data_available);
                    // this.info("New temperature data available: " + result.temp_data_available);
                    resolve("Data ready interrupt triggered as expected");
                }
            }.bindenv(this))
            // Enable the data ready interrupt
            _tempHumid.setMode(HTS221_MODE.CONTINUOUS, 1);
            _tempHumid.configureDataReadyInterrupt(true);
            // Clear the Data interrupt table
            _tempHumid.read();
        }.bindenv(this))
    }

        // Helper Reset methods
    function resetPressure() {
        // Software reset for pressure sensor
        _setReg(0xB8, 0x11, 0x14);
    }

    function resetAccel() {
        local addr = 0x32;
        // Set default values for registers
        _setReg(addr, 0x20, 0x07);
        _setReg(addr, 0x21, 0x00);
        _setReg(addr, 0x22, 0x00);
        _setReg(addr, 0x23, 0x00);
        _setReg(addr, 0x24, 0x00);
        _setReg(addr, 0x25, 0x00);
        _setReg(addr, 0x30, 0x00);
        _setReg(addr, 0x32, 0x00);
        _setReg(addr, 0x33, 0x00);
        _setReg(addr, 0x38, 0x00);
        _setReg(addr, 0x39, 0x00);
        _setReg(addr, 0x3A, 0x00);
        _setReg(addr, 0x3B, 0x00);
        _setReg(addr, 0x3C, 0x00);
        _setReg(addr, 0x2E, 0x00);
        _setReg(addr, 0x2E, 0x00);
    }

    function _setReg(addr, reg, val) {
        _i2c.write(addr, format("%c%c", reg, (val & 0xff)));
    }

    function tearDown() {
        // Make sure interrupt pin and table are cleared.
        _tempHumid.configureDataReadyInterrupt(false);
        _tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        _tempHumid.read();
        // Power down sensor
        _tempHumid.setMode(HTS221_MODE.POWER_DOWN);
    }

}

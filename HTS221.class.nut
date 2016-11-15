enum HTS221_MODE {
    POWER_DOWN,
    ONE_SHOT,
    CONTINUOUS
}

//Temperature Humidity
class HTS221 {

    static VERSION = [1, 0, 1];

    // 8 bit Register addresses
    static AV_CONF = 0x10;
    static CTRL_REG1   = 0x20;
    static CTRL_REG2   = 0x21;
    static CTRL_REG3   = 0x22;
    static STATUS_REG   = 0x27;
    static T0_DEGC_x8 = 0x32; // unsigned 8bit
    static T1_DEGC_x8 = 0x33; // unsigned 8bit
    static T1_T0_MSB = 0x35; // unsigned 8bit
    static H0_RH_x2 = 0x30; // unsigned 8bit
    static H1_RH_x2 = 0x31; // unsigned 8bit
    static REG_WHO_AM_I = 0x0F; // Return value is 0xBC

    // 16 bit signed Registers
    // MSB of SUB address set to 1 to enable auto increased multiple data read/write
    static REG_HUM_OUT_16   = 0xA8;
    static REG_TEMP_OUT_16  = 0xAA;
    static REG_T0_OUT_16 = 0xBC;
    static REG_T1_OUT_16 = 0xBE;
    static REG_H0_OUT_16 = 0xB6;
    static REG_H1_OUT_16 = 0xBA;

    // Class Constants
    static SENSITIVITY_HUM = 256.0; // Sensitivity constant in LSB/%rH
    static SENSITIVITY_TEMP = 64.0; // Sensitivity constant in LSB/*C
    static INT_PIN_ACTIVELOW = 0x80;
    static INT_PIN_OPENDRAIN = 0x40;
    static INT_DDRY_ENABLE = 0x04;
    static POWER_DOWN_READING_ERROR = "Sensor in power down mode.  Please change mode to take a reading."
    static MAX_MEAS_TIME_SECONDS = 0.5; // seconds; time to complete one-shot pressure conversion

    // Class variables
    _i2c  = null;
    _addr = null;

    _mode = null;
    _t_slope = null;
    _t_offset = null;
    _h_slope = null;
    _h_offset = null;

    constructor(i2c, addr = 0xBE) {
        _i2c  = i2c;
        _addr = addr;

        // Get mode and temperature and humidity calibration values to store locally
        _getCalibrationVariables();
    }

    function setResolution(tempRes, humidRes) {
        local val = _getReg(AV_CONF) & 0xC0;
        local temp = _calculateTempResolution(tempRes);
        local humid = _calculateHumidResolution(humidRes);
        val = val | temp.AVGT | humid.AVGH;

        _setReg(AV_CONF, val);
        return {"temperatureResolution" : temp.resolution, "humidityResolution" : humid.resolution};
    }

    function getResolution() {
        local val = _getReg(AV_CONF);
        return {"temperatureResolution" : _getTempResolution(val), "humidityResolution" : _getHumidResolution(val)};
    }

    function setMode(mode, dataRate = null) {
        local val = _getReg(CTRL_REG1);

        switch (mode) {
            case HTS221_MODE.CONTINUOUS :
                // use stored data rate if none passed in
                if (dataRate == null) dataRate = getDataRate(val);
                // Set to continuous only if data rate is not 0
                if (dataRate != 0) {
                    dataRate = _setDataRate(dataRate, val, true);
                    // Store mode locally
                    _mode = HTS221_MODE.CONTINUOUS;
                    break;
                }
            case HTS221_MODE.ONE_SHOT :
                // Set dataRate to 0, and enable sensor
                dataRate = _setDataRate(0, val, true);
                // Store mode locally
                _mode = HTS221_MODE.ONE_SHOT;
                break;
            default :
                // Set to Power down mode
                _setRegBit(CTRL_REG1, 7, 0);
                // store mode locally
                _mode = HTS221_MODE.POWER_DOWN;
                return null;
        }
        return dataRate;
    }

    function getDataRate(val = null) {
        if (val == null) val = _getReg(CTRL_REG1);
        local rate = 0;
        val = val & 0x03;

        if (val == 0x01) {
            rate = 1;
        } else if (val == 0x02) {
            rate = 7;
        } else if (val == 0x03) {
            rate = 12.5;
        }

        return rate;
    }

    function getMode() {
        local val = _getReg(CTRL_REG1);
        if (val >> 7 == 0x00) { return HTS221_MODE.POWER_DOWN; }
        return ( (val & 0x03) == 0) ? HTS221_MODE.ONE_SHOT : HTS221_MODE.CONTINUOUS;
    }

    // Read data from the Barometer
    // Returns a table {humidity: <data>, temperature: <data>}
    function read(cb = null) {

        local result = {"temperature": null, "humidity": null};
        local cbTimer = 0;

        if (_mode == HTS221_MODE.POWER_DOWN) {
            result.error <- POWER_DOWN_READING_ERROR;
        } else {
            // Handle One-shot conversion
            if (_mode == HTS221_MODE.ONE_SHOT) {
                // Set One-shot enable bit to 1
                _setRegBit(CTRL_REG2, 0, 1);
                // Ensure sensor has time to take reading
                cb ? cbTimer = MAX_MEAS_TIME_SECONDS : imp.sleep(MAX_MEAS_TIME_SECONDS);
            }

            // Take a reading
            try {
                local hum_raw = _getSignedReg16LE(REG_HUM_OUT_16);
                local temp_raw = _getSignedReg16LE(REG_TEMP_OUT_16);
                result.humidity = _h_slope*hum_raw + _h_offset;
                result.temperature = _t_slope*temp_raw + _t_offset;
            } catch (err) {
                result.error <- err;
            }
        }

        if (cb == null) { return result; }
        imp.wakeup(cbTimer, function() { cb(result); });
    }

    function configureDataReadyInterrupt(enable, options = 0) {
        val = _getReg(CTRL_REG3);
        // Check and set the options
        val = (options & INT_PIN_ACTIVELOW) ?  (val | INT_PIN_ACTIVELOW) : (val & ~ INT_PIN_ACTIVELOW);
        val = (options & INT_PIN_OPENDRAIN) ?  (val | INT_PIN_OPENDRAIN) : (val & ~ INT_PIN_OPENDRAIN);
        val = (enable) ? (val | INT_DDRY_ENABLE) : (val & ~INT_DDRY_ENABLE);

        _setReg(CTRL_REG3, val & 0xFF);
    }

    function getInterruptStatus() {
        local val = _getReg(STATUS_REG);
        return { "humidity_data_available" : (val & 0x02) ? true : false,
                     "temp_data_available" : (val & 0x01) ? true : false }
    }

    function getDeviceID() {
        return _getReg(REG_WHO_AM_I);
    }

    // Dump all the register's raw values to log
    function dumpRegs() {
        server.log(format("AV_CONF  0x%02X", _getReg(AV_CONF)));

        server.log(format("CTRL_REG1    0x%02X", _getReg(CTRL_REG1)));
        server.log(format("CTRL_REG2    0x%02X", _getReg(CTRL_REG2)));
        server.log(format("CTRL_REG3    0x%02X", _getReg(CTRL_REG3)));
        server.log(format("STATUS_REG    0x%02X", _getReg(STATUS_REG)));

        server.log(format("REG_HUM_OUT_16    0x%04X", _getReg(REG_HUM_OUT_16)));
        server.log(format("REG_TEMP_OUT_16    0x%04X", _getReg(REG_TEMP_OUT_16)));

        server.log(format("REG_WHO_AM_I  0x%02X", _getReg(REG_WHO_AM_I)));
    }

    //-------------------- PRIVATE METHODS --------------------//
    function _signedConvert(value, mask) {
        local topbit = ((mask+1)/ 2);
        if (value & topbit) {
            // Negative
            value = ~(value & mask) + 1;
            return -1 * (value & mask);
        }
        return value;
    }

    function _getSignedReg16LE(reg) {
        // Read both bytes in one I2C operation
        local regs = _i2c.read(_addr, reg.tochar(), 2);
        if (regs == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        local raw = (regs[0] | (regs[1] << 8));

        // Two's complement conversion if necessary
        return _signedConvert(raw, 0xFFFF);
    }

    function _getReg(reg) {
        local result = _i2c.read(_addr, reg.tochar(), 1);
        if (result == null) {
            throw "I2C read error: " + _i2c.readerror();
        }
        return result[0];
    }

    function _setReg(reg, val) {
        local result = _i2c.write(_addr, format("%c%c", reg, (val & 0xFF)));
        if (result) {
            throw "I2C write error: " + result;
        }
        return result;
    }

    function _setRegBit(reg, bit, state) {
        local val = _getReg(reg);
        if (state == 0) {
            val = val & ~(0x01 << bit);
        } else {
            val = val | (0x01 << bit);
        }
        return _setReg(reg, val);
    }

    function _getCalibrationVariables() {
        // Get Humidity calibration variables
        local H0_rH = _getReg(H0_RH_x2) / 2.0;
        local H1_rH = _getReg(H1_RH_x2) / 2.0;

        local H0_T0_OUT = _getSignedReg16LE(REG_H0_OUT_16);
        local H1_T0_OUT = _getSignedReg16LE(REG_H1_OUT_16);
        // Calculate Humidity reading variables
        _h_slope = ( H1_rH - H0_rH ) / ( H1_T0_OUT - H0_T0_OUT );
        _h_offset = H0_rH - ( _h_slope * H0_T0_OUT );

        // Get Temperature calibration variables
        local MSB_TdegC = _getReg(T1_T0_MSB);
        local T0_MSB = (MSB_TdegC & 0x03) << 8; // bit 0 (T0-8) & bit 1 (T0-9)
        local T1_MSB = (MSB_TdegC & 0x0C) << 6; // bit 2 (T1-8) & bit 3 (T1-9)
        local T0_degC = (T0_MSB | _getReg(T0_DEGC_x8)) / 8.0;
        local T1_degC = (T1_MSB | _getReg(T1_DEGC_x8)) / 8.0;
        local T0_OUT = _getSignedReg16LE(REG_T0_OUT_16);
        local T1_OUT = _getSignedReg16LE(REG_T1_OUT_16);
        // Calculate Temperature reading variables
        _t_slope = ( T1_degC - T0_degC ) / ( T1_OUT - T0_OUT );
        _t_offset = T0_degC - ( _t_slope * T0_OUT );

        // Get mode
        _mode = getMode();
    }

    function _calculateTempResolution(resolution) {
        local AVGT = 0x00;  // AVGT = 000

        if (resolution < 4) {
            resolution = 2;
        } else if (resolution < 8) {
            resolution = 4;
            AVGT = 0x08; // AVGT = 001
        } else if (resolution < 16) {
            resolution = 8;
            AVGT = 0x10;  // AVGT = 010
        } else if (resolution < 32) {
            resolution = 16;
            AVGT = 0x18;  // AVGT = 011
        } else if (resolution < 64) {
            resolution = 32;
            AVGT = 0x20;  // AVGT = 100
        } else if (resolution < 128) {
            resolution = 64;
            AVGT = 0x28;  // AVGT = 101
        } else if (resolution < 256) {
            resolution = 128;
            AVGT = 0x30;  // AVGT = 110
        } else {
            resolution = 256;
            AVGT = 0x38;  // AVGT = 111;
        }

        return {"resolution" : resolution, "AVGT": AVGT}
    }

    function _calculateHumidResolution(resolution) {
        // clear AVGH bits
        local AVGH = 0x00;  // AVGH = 000

        if (resolution < 8) {
            resolution = 4;
        } else if (resolution < 16) {
            resolution = 8;
            AVGH = 0x01; // AVGH = 001
        } else if (resolution < 32) {
            resolution = 16;
            AVGH = 0x02;  // AVGH = 010
        } else if (resolution < 64) {
            resolution = 32;
            AVGH = 0x03;  // AVGH = 011
        } else if (resolution < 128) {
            resolution = 64;
            AVGH = 0x04;  // AVGH = 100
        } else if (resolution < 256) {
            resolution = 128;
            AVGH = 0x05;  // AVGH = 101
        } else if (resolution < 512) {
            resolution = 256;
            AVGH = 0x06;  // AVGH = 110
        } else {
            resolution = 512;
            AVGH = 0x07;  // AVGH = 111;
        }

        return {"resolution" : resolution, "AVGH": AVGH}
    }

    function _getTempResolution(regVal) {
        regVal = (regVal & 0x38) >> 3;
        local resolution = null;

        if (regVal == 0x00) {
            resolution = 2;
        } else if (regVal == 0x01) {
            resolution = 4;
        } else if (regVal == 0x02) {
            resolution = 8;
        } else if (regVal == 0x03) {
            resolution = 16;
        } else if (regVal == 0x04) {
            resolution = 32;
        } else if (regVal == 0x05) {
            resolution = 64;
        } else if (regVal == 0x06) {
            resolution = 128;
        } else if (regVal == 0x07) {
            resolution = 256;
        }

        return resolution;
    }

    function _getHumidResolution(regVal) {
        regVal = regVal & 0x07;
        local resolution = null;

        if (regVal == 0x00) {
            resolution = 4;
        } else if (regVal == 0x01) {
            resolution = 8;
        } else if (regVal == 0x02) {
            resolution = 16;
        } else if (regVal == 0x03) {
            resolution = 32;
        } else if (regVal == 0x04) {
            resolution = 64;
        } else if (regVal == 0x05) {
            resolution = 128;
        } else if (regVal == 0x06) {
            resolution = 256;
        } else if (regVal == 0x07) {
            resolution = 512;
        }

        return resolution;
    }

    function _setDataRate(rate, val, setEnable = false) {
        if (setEnable) val = val | 0x80;

        // clear datarate bits
        val = val & 0xFC;
        if (rate < 1) {
            rate = 0;
        } else if (rate < 7) {
            rate = 1;
            val = val | 0x01;
        } else if (rate <12.5) {
            rate = 7;
            val = val | 0x02;
        } else {
            rate = 12.5;
            val = val | 0x03;
        }

        _setReg(CTRL_REG1, val);
        return rate;
    }
}

/**
 * @copyright MbientLab License (LICENSE.md)
 * @file humidity_bme280.h
 * @brief Communicates with the BME280 humidity sensor, only available on MetaEnvironment boards
 */
#pragma once

#include "sensor_common.h"

#ifdef	__cplusplus
extern "C" {
#endif

/**
 * Supported oversampling modes on the BME280 humidity sensor
 */
typedef enum {
    MBL_MW_HUMIDITY_BME280_OVERSAMPLING_1X= 1,
    MBL_MW_HUMIDITY_BME280_OVERSAMPLING_2X,
    MBL_MW_HUMIDITY_BME280_OVERSAMPLING_4X,
    MBL_MW_HUMIDITY_BME280_OVERSAMPLING_8X,
    MBL_MW_HUMIDITY_BME280_OVERSAMPLING_16X
} MblMwHumidityBme280Oversampling;

/**
 * Retrieves the data signal representing humidity data
 * Relative humidity is returned as a percentage.
 * @param board         Board the humidity sensor resides on
 * @return Pointer to the data signal
 * UINT32 is return signal data type 
 */
METAWEAR_API MblMwDataSignal* mbl_mw_humidity_bme280_get_percentage_data_signal(const MblMwMetaWearBoard *board);
/**
 * Sets the oversampling mode
 * For the humidity measurement, oversampling is possible to reduce the noise. 
 * The resolution of the humidity measurement is fixed at 16 bit ADC output.
 * See MblMwHumidityBme280Oversampling for allowed oversampling values
 * @param board             Board the humidity sensor resides on
 * @param oversampling      New oversampling mode
 */
METAWEAR_API void mbl_mw_humidity_bme280_set_oversampling(const MblMwMetaWearBoard *board, MblMwHumidityBme280Oversampling oversampling);

#ifdef	__cplusplus
}
#endif

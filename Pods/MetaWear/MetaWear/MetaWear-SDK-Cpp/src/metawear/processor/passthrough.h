/**
 * @copyright MbientLab License
 * @file passthrough.h
 * @brief Gate that only allows data though based on a user configured internal state
 */
#pragma once

#include "processor_common.h"

#ifdef	__cplusplus
extern "C" {
#endif

/**
 * Operation modes for the processor
 */
typedef enum {
    MBL_MW_PASSTHROUGH_MODE_ALL = 0,             ///< Allow all data through
    MBL_MW_PASSTHROUGH_MODE_CONDITIONAL,         ///< Only allow data through if count > 0
    MBL_MW_PASSTHROUGH_MODE_COUNT                ///< Only allow a fixed number of data samples through
} MblMwPassthroughMode;

/**
 * Create a passthrough processor.  
 * On a pass-count, only the count # of samples will go through and then the processor will shut off.
 * On a pass-conditional, if the count=0, all data is blocked. if the count>0, all data is passed.
 * Gate that only allows data though based on a user configured internal state.
 * A pointer representing the processor will be passed back to the user via a callback function.
 * @param source                Data signal providing the input for the processor
 * @param mode                  Processor's operation mode
 * @param count                 Internal count to initial the processor with
 * @param context               Pointer to additional data for the callback function
 * @param processor_created     Callback function to be executed when the processor is created
 */
METAWEAR_API int32_t mbl_mw_dataprocessor_passthrough_create(MblMwDataSignal *source, MblMwPassthroughMode mode, uint16_t count,
        void *context, MblMwFnDataProcessor processor_created);
/**
 * Modify the internal count of the passthrough processor
 * @param passthrough           Passthrough processor to modify
 * @param new_count             New internal count
 * @return MBL_MW_STATUS_OK if processor state was updated, MBL_MW_STATUS_WARNING_INVALID_PROCESSOR_TYPE if 
 * a non-passthrough processor was passed in
 */
METAWEAR_API int32_t mbl_mw_dataprocessor_passthrough_set_count(MblMwDataProcessor *passthrough, uint16_t new_count);
/**
 * Modify the passthrough configuration
 * @param passthrough           Passthrough processor to update
 * @param mode                  New operation mode to use
 * @param count                 New initial count
 * @return MBL_MW_STATUS_OK if processor configuration was updated, MBL_MW_STATUS_WARNING_INVALID_PROCESSOR_TYPE if 
 * a non-passthrough processor was passed in
 */
METAWEAR_API int32_t mbl_mw_dataprocessor_passthrough_modify(MblMwDataProcessor *passthrough, MblMwPassthroughMode mode, uint16_t count);

#ifdef	__cplusplus
}
#endif

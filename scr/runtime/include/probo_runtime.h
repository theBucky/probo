#ifndef PROBO_RUNTIME_H
#define PROBO_RUNTIME_H

#include <stdint.h>

enum {
  PROBO_INTENSITY_SLOW = 0,
  PROBO_INTENSITY_MEDIUM = 1,
};

typedef struct {
  int32_t delta_axis1;
  int32_t delta_axis2;
  uint8_t intensity;
  uint8_t is_continuous;
  uint8_t has_phase;
} probo_wheel_input_t;

typedef struct {
  uint8_t rewrite;
  int32_t out_lines_x;
  int32_t out_lines_y;
} probo_wheel_output_t;

probo_wheel_output_t probo_process_wheel(probo_wheel_input_t input);

#endif

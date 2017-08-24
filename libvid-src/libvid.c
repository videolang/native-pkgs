#include <stdlib.h>
#include <stdio.h>
#include <libavutil/util.h>

void (*racket_log_callback)(void*, int, const char*) = NULL;

void set_racket_log_callback(void (*callback)()) {
  racket_log_callback = callback;
}

void ffmpeg_log_callback(void * avcl,
                         int level,
                         const char * fmt,
                         va_list vl) {
  int buffsize;
  char find_size_buf[64];
  char *buff;
  va_list size_vl;

  va_copy(size_vl, vl);
  buffsize = vsnprintf(find_size_buf, 64, fmt, size_vl);
  buff = malloc((buffsize + 1) * sizeof(char));
  vsnprintf(buff, buffsize + 1, fmt, vl);
  if(racket_log_callback) {
    racket_log_callback(avcl, level, buff);
  } else {
    free(buff);
  }
}

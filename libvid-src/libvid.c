/*
   Copyright 2016-2017 Leif Andersen, Stephen Chang

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

/**
  This library exists ONLY because va_list doesn't currently wrok with libffi.
  (Or at least Racket's build of it. So this library only
  expands a log message and passes it along to Racket. It is
  NOT necesarry to run video.
  */

#include <stdlib.h>
#include <stdio.h>
#include <libavutil/avutil.h>

void (*racket_log_callback)(void* avclass,
                            int log_level,
                            int msg_len,
                            const char* msg) = NULL;

/**
 * @brief set_racket_log_callback
 *
 * The call to set the Racket function that serves as a callback.
 *
 * Note that only ONE function can be used at a time.
 */
void set_racket_log_callback(void (*callback)(void*, int, int, const char*)) {
  racket_log_callback = callback;
}

#define FIND_BUFF_SIZE 32

/**
 * @brief ffmpeg_log_callback
 *
 * The function that will intercept the av_log message. Note
 * that Racket is responsible for connecting it with ffmpeg
 *
 * @param avcl
 * @param level
 * @param fmt
 * @param vl
 */
void ffmpeg_log_callback(void * avcl,
                         int level,
                         const char * fmt,
                         va_list vl) {
  int buffsize;
  char find_size_buf[FIND_BUFF_SIZE];
  char *buff;
  va_list size_vl;

  if(racket_log_callback) {
    va_copy(size_vl, vl);
    buffsize = vsnprintf(find_size_buf, FIND_BUFF_SIZE, fmt, size_vl);
    buff = malloc((buffsize + 1) * sizeof(char));
    vsnprintf(buff, buffsize + 1, fmt, vl);
    racket_log_callback(avcl, level, buffsize, buff);
  } else {
    vsnprintf(find_size_buf, FIND_BUFF_SIZE, fmt, vl);
  }
}

int libvid_get_version_major() {
  return 0;
}

int libvid_get_version_minor() {
  return 2;
}

int libvid_get_version_patch() {
  return 0;
}

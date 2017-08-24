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

#include <stdlib.h>
#include <stdio.h>
#include <libavutil/avutil.h>

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

int libvid_get_version_major() {
  return 0;
}

int libvid_get_version_minor() {
  return 2;
}

int libvid_get_version_patch() {
  return 0;
}

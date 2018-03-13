/*
   Copyright 2016-2017 Leif Andersen

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
#include <stdarg.h>
#include <stdio.h>
#include <libavutil/avutil.h>
#include <libavutil/bprint.h>

#define RACKET_CALLBACK_TYPES int log_level,\
                              AVBPrint* name,\
                              AVBPrint* msg

#ifdef __MINGW32__
#define LIBVID_DLL __declspec(dllexport)
LIBVID_DLL void set_racket_log_callback(void(*callback)(RACKET_CALLBACK_TYPES));
LIBVID_DLL void ffmpeg_log_callback(void *avcl, int level, const char *fmt, va_list vl);
#endif


void (*racket_log_callback)(RACKET_CALLBACK_TYPES) = NULL;


/**
 * @brief set_racket_log_callback
 *
 * The call to set the Racket function that serves as a callback.
 *
 * Note that only ONE function can be used at a time.
 */
void set_racket_log_callback(void (*callback)(RACKET_CALLBACK_TYPES)){
  racket_log_callback = callback;
}

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
  AVBPrint *name = malloc(sizeof(AVBPrint));
  AVBPrint *message = malloc(sizeof(AVBPrint));

  av_bprint_init(name, 0, 1);
  av_bprint_init(message, 0, 65536); // 2^16

  if(avcl) {
    av_bprintf(name, "%s", ((AVClass*)(*(void**)avcl))->class_name);
  }

  av_vbprintf(message, fmt, vl);

  if(racket_log_callback && 0) { // XXX remove 0
    racket_log_callback(level, name, message);
  } else {
    av_bprint_finalize(message, NULL);
    free(name);
    free(message);
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


/**
 *  This value returned by this function is used
 *  internally for Video development. It is only to
 *  be used as a tag to track which version of libvid
 *  is installed between Video releases.
 */
int libvid_get_version_prerelease() {
  return 0;
}

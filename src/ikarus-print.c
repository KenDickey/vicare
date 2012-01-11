/*
 * Ikarus Scheme -- A compiler for R6RS Scheme.
 * Copyright (C) 2006,2007,2008  Abdulaziz Ghuloum
 * Modified by Marco Maggi <marco.maggi-ipsu@poste.it>
 *
 * This program is free software:  you can redistribute it and/or modify
 * it under  the terms of  the GNU General  Public License version  3 as
 * published by the Free Software Foundation.
 *
 * This program is  distributed in the hope that it  will be useful, but
 * WITHOUT  ANY   WARRANTY;  without   even  the  implied   warranty  of
 * MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE.  See  the GNU
 * General Public License for more details.
 *
 * You should  have received  a copy of  the GNU General  Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "ikarus.h"

extern ikpcb* the_pcb;

static void print(FILE* fh, ikptr x);

void
ik_fprint (FILE* fh, ikptr x)
{
  print(fh, x);
}
void
ik_print (ikptr x)
{
  print(stderr, x);
  fprintf(stderr, "\n");
}
void
ik_print_no_newline (ikptr x)
{
  print(stderr, x);
}

const static char* char_string[128] = {
  "#\\nul","#\\soh","#\\stx","#\\etx","#\\eot","#\\enq","#\\ack","#\\bel",
  "#\\bs", "#\\tab","#\\newline", "#\\vt", "#\\ff", "#\\return", "#\\so",
  "#\\si",
  "#\\dle","#\\dc1","#\\dc2","#\\dc3","#\\dc4","#\\nak","#\\syn","#\\etb",
  "#\\can","#\\em", "#\\sub","#\\esc","#\\fs", "#\\gs", "#\\rs", "#\\us",
  "#\\space","#\\!","#\\\"","#\\#","#\\$","#\\%","#\\&","#\\'",
  "#\\(","#\\)","#\\*","#\\+","#\\,","#\\-","#\\.","#\\/",
  "#\\0","#\\1","#\\2","#\\3","#\\4","#\\5","#\\6","#\\7",
  "#\\8","#\\9","#\\:","#\\;","#\\<","#\\=","#\\>","#\\?",
  "#\\@","#\\A","#\\B","#\\C","#\\D","#\\E","#\\F","#\\G",
  "#\\H","#\\I","#\\J","#\\K","#\\L","#\\M","#\\N","#\\O",
  "#\\P","#\\Q","#\\R","#\\S","#\\T","#\\U","#\\V","#\\W",
  "#\\X","#\\Y","#\\Z","#\\[","#\\\\","#\\]","#\\^","#\\_",
  "#\\`","#\\a","#\\b","#\\c","#\\d","#\\e","#\\f","#\\g",
  "#\\h","#\\i","#\\j","#\\k","#\\l","#\\m","#\\n","#\\o",
  "#\\p","#\\q","#\\r","#\\s","#\\t","#\\u","#\\v","#\\w",
  "#\\x","#\\y","#\\z","#\\{","#\\|","#\\}","#\\~","#\\del"};

static void
print (FILE* fh, ikptr x)
{
  if (IK_IS_FIXNUM(x)){
    fprintf(fh, "%ld", unfix(x));
  }
  else if (x == false_object){
    fprintf(fh, "#f");
  }
  else if (x == true_object){
    fprintf(fh, "#t");
  }
  else if (x == null_object){
    fprintf(fh, "()");
  }
  else if (IK_IS_CHAR(x)){
    unsigned long int i = ((long int)x) >> char_shift;
    if (i < 128){
      fprintf(fh, "%s", char_string[i]);
    } else {
      fprintf(fh, "#\\x%lx", i);
    }
  }
  else if (IK_TAGOF(x) == vector_tag){
    ikptr first_word = ref(x, off_vector_length);
    if (IK_IS_FIXNUM(first_word)){
      ikptr len = first_word;
      if (len == 0){
        fprintf(fh, "#()");
      } else {
        fprintf(fh, "#(");
        ikptr data = x + off_vector_data;
        print(fh, ref(data, 0));
        ikptr i = (ikptr)wordsize;
        while(i<len){
          fprintf(fh, " ");
          print(fh, ref(data,i));
          i += wordsize;
        }
        fprintf(fh, ")");
      }
    } else if (first_word == symbol_tag){
      ikptr str = ref(x, off_symbol_record_string);
      ikptr fxlen = ref(str, off_string_length);
      int len = unfix(fxlen);
      int * data = (int*)(str + off_string_data);
      int i;
      for(i=0; i<len; i++){
        char c = (data[i]) >> char_shift;
        fprintf(fh, "%c", c);
      }
    } else if (IK_TAGOF(first_word) == rtd_tag) {
      int	i;
      ikptr	s_rtd		 = ref(x, off_record_rtd);;
      ikptr	number_of_fields = IK_UNFIX(ref(s_rtd, off_rtd_length));
      if (s_rtd == the_pcb->base_rtd) {
	fprintf(fh, "#[rtd: ");
      } else {
	fprintf(fh, "#[struct nfields=%ld rtd=", number_of_fields);
	print(fh, ref(s_rtd, off_rtd_name));
	fprintf(fh, ": ");
      }
      for (i=0; i<number_of_fields; ++i) {
	if (i) fprintf(fh, ", ");
	print(fh, IK_FIELD(x, i));
      }
      fprintf(fh, "]");
    } else {
      fprintf(fh, "#<unknown first_word=%p>", (void*)first_word);
    }
  }
  else if (is_closure(x)){
    fprintf(fh, "#<procedure>");
  }
  else if (IK_IS_PAIR(x)){
    fprintf(fh, "(");
    print(fh, ref(x, off_car));
    ikptr d = ref(x, off_cdr);
    /* fprintf(stderr, "d=0x%016lx\n", (long int)d); */
    while(1){
      if (IK_IS_PAIR(d)){
        fprintf(fh, " ");
        print(fh, ref(d, off_car));
        d = ref(d, off_cdr);
      }
      else if (d == null_object){
        fprintf(fh, ")");
        return;
      }
      else {
        fprintf(fh, " . ");
        print(fh, d);
        fprintf(fh, ")");
        return;
      }
    }
  }
  else if (IK_TAGOF(x) == string_tag){
    ikptr fxlen = ref(x, off_string_length);
    int len = unfix(fxlen);
    int * data = (int*)(x + off_string_data);
    fprintf(fh, "\"");
    int i;
    for(i=0; i<len; i++){
      char c = (data[i]) >> char_shift;
      if ((c == '\\') || (c == '"')){
        fprintf(fh, "\\");
      }
      fprintf(fh, "%c", c);
    }
    fprintf(fh, "\"");
  }
  else if (IK_TAGOF(x) == bytevector_tag){
    ikptr fxlen = ref(x, off_bytevector_length);
    int len = unfix(fxlen);
    unsigned char* data = (unsigned char*)(x + off_bytevector_data);
    fprintf(fh, "#vu8(");
    int i;
    for(i=0; i<(len-1); i++){
      fprintf(fh, "%d ", data[i]);
    }
    if (i < len){
      fprintf(fh, "%d", data[i]);
    }
    fprintf(fh, ")");
  }
  else {
    fprintf(fh, "#<unknown>");
  }
}

/* end of file*/

// Maven Dependency Manager
// Goals:
// - Search maven.central for artifacts
// - Add found dependencies to libs.version.toml's

import std::io;
import curl;

bitstruct CurlHFlags : uint {
  bool header;
}


macro log(String format, args...) {
  io::printf("[%s:%d]: ", $$FILE, $$LINE);
  io::printfn(format, ...args);
}

// alias Curl_write_callback = fn usz(char* buffer, usz size, usz nitems, void* outstream);
fn usz write_call_back(
  char* content, 
  usz size, 
  usz num_items,
  DString* outstream)  {
  // log("write called");
  String text = (String)content[:num_items];
  // log("content %s", text);
  outstream.append(text);
  return size * num_items;
}

fn usz header_call_cack(
  ZString content,
  usz size,
  usz num_items,
  void* userdata
) {
  log("header called");
  String text = (String)content[:num_items];
  log("%s", text);
  return size * num_items;
}


fn void get(String url) {
  log("Download url: %s", url);
  curl::global_init(1);
  defer curl::global_cleanup();


  Curl* conn = curl::easy_init();
  defer curl::easy_cleanup(conn);
  curl::easy_setopt(conn, curl::CURLOPT_URL, url);
  // curl::easy_setopt(conn, curl::CURLOPT_FOLLOWLOCATION);
  Allocator temp = tmem;
  DString response_buffer;
  response_buffer.init(temp);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_WRITEFUNCTION, 
    &write_call_back);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_WRITEDATA, 
    &response_buffer);
  // curl::easy_setopt(
  //   conn, 
  //   curl::CURLOPT_HEADERFUNCTION, 
  //   &header_call_cack);
  curl::CURLcode result = curl::easy_perform(conn);
  if(result != curl::CURLcode.CURLE_OK) {
    io::printfn("Error occurred '%s'", result);
  } else {
    io::printn("OK");
  }
  io::printn("=== RESPONSE ===");
  io::printn(response_buffer);
  io::printn("=== RESPONSE ===");
  // CurlHFlags flags = {.header = true };
  // Header* header;
  // CURLHcode hcode = curl::easy_header(
  //   conn, 
  //   "Content-type", 
  //   0, 
  //   (uint)flags, 
  //   -1, 
  //   &header);
  // io::printn(hcode);
  // io::printn((ZString)header.value);
}

fn int main(String[] args)
{
  Version_info_data* version_info = curl::version_info(curl::CURLversion.CURLVERSION_LAST);
  io::printfn("Curl Version: %s", (ZString)version_info.version);
  get("https://google.com");
	io::printn("MDM Version 0.1.0");
  return 0;
}

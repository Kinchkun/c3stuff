// Maven Dependency Manager
// Goals:
// - Search maven.central for artifacts
// - Add found dependencies to libs.version.toml's

import std::io;
import curl;


macro log(String format, args...) {
  io::printf("[%s:%d]: ", $$FILE, $$LINE);
  io::printfn(format, ...args);
}

// alias Curl_write_callback = fn usz(char* buffer, usz size, usz nitems, void* outstream);
fn usz write_call_back(
  char* content, 
  usz size, 
  usz num_items,
  void* outstream) {
  log("callback called");
  String text = (String)content[:num_items];
  log("content %s", text);
  return size * num_items;
}

fn usz header_call_cack(
  ZString content,
  usz size,
  usz num_items,
  void* userdata
) {
  return size;
}


fn void get(String url) {
  log("Download url: %s", url);
  curl::global_init(1);
  defer curl::global_cleanup();

  Curl* conn = curl::easy_init();
  defer curl::easy_cleanup(conn);
  curl::easy_setopt(conn, curl::CURLOPT_URL, url);
  // curl::easy_setopt(conn, curl::CURLOPT_FOLLOWLOCATION);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_WRITEFUNCTION, 
    &write_call_back);
  curl::CURLcode result = curl::easy_perform(conn);
  if(result != curl::CURLcode.CURLE_OK) {
    io::printfn("Error occurred '%s'", result);
  } else {
    io::printn("OK");
  }
}

fn int main(String[] args)
{
  get("https://google.com");
	io::printn("MDM Version 0.1.0");
  return 0;
}

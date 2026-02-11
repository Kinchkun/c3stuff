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

struct Response {
  DString headers;
  DString body;
}

fn void Response.init(&self, Allocator alloc) {
  self.headers.init(alloc);
  self.body.init(alloc);
}

fn usz write_call_back(
  char* content, 
  usz size, 
  usz num_items,
  DString* outstream)  {
  String text = (String)content[:num_items];
  outstream.append(text);
  return size * num_items;
}

fn usz header_call_cack(
  ZString content,
  usz size,
  usz num_items,
  DString* outstream
) {
  String text = (String)content[:num_items];
  outstream.append(text);
  return size * num_items;
}


fn void get(String url) {
  log("Download url: %s", url);
  curl::global_init(1);
  defer curl::global_cleanup();

  Curl* conn = curl::easy_init();
  defer curl::easy_cleanup(conn);
  curl::easy_setopt(conn, curl::CURLOPT_URL, url);
  curl::easy_setopt(conn, curl::CURLOPT_FOLLOWLOCATION);
  char[8192] buffer;
  ArenaAllocator arena;
  arena.init(&buffer);
  Response response;
  response.init(&arena);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_WRITEFUNCTION, 
    &write_call_back);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_WRITEDATA, 
    &&response.body);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_HEADERFUNCTION, 
    &header_call_cack);
  curl::easy_setopt(
    conn, 
    curl::CURLOPT_HEADERDATA, 
    &response.headers);
  curl::CURLcode result = curl::easy_perform(conn);
  if(result != curl::CURLcode.CURLE_OK) {
    io::printfn("Error occurred '%s'", result);
  }
  io::printn("=== HEADERS ===");
  io::printn(response.headers);
  io::printn("=== RESPONSE ===");
  io::printn(response.body);
}

fn int main(String[] args)
{
  Version_info_data* version_info = curl::version_info(curl::CURLversion.CURLVERSION_LAST);
  io::printfn("Curl Version: %s", (ZString)version_info.version);
  get("https://jsonplaceholder.typicode.com/posts/1");
  // io::printn("MDM Version 0.1.0");
  return 0;
}

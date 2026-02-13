// Maven Dependency Manager
// Goals:
// - Search maven.central for artifacts
// - Add found dependencies to libs.version.toml's

import std::io;
import curl;
import hc;

bitstruct CurlHFlags : uint {
  bool header;
}


macro log(String format, args...) {
  io::printf("[%s:%d]: ", $$FILE, $$LINE);
  io::printfn(format, ...args);
}

// struct Response {
//   DString headers;
//   DString body;
// }
//
// fn void Response.init(&self, Allocator alloc) {
//   self.headers.init(alloc);
//   self.body.init(alloc);
// }
//
// fn usz write_call_back(
//   char* content, 
//   usz size, 
//   usz num_items,
//   DString* outstream)  {
//   String text = (String)content[:num_items];
//   outstream.append(text);
//   return size * num_items;
// }
//
// fn usz header_call_cack(
//   ZString content,
//   usz size,
//   usz num_items,
//   DString* outstream
// ) {
//   String text = (String)content[:num_items];
//   outstream.append(text);
//   return size * num_items;
// }


fn void? get(String url) {
  log("Download url: %s", url);
  // defer curl::global_cleanup();
  //
  // Curl* conn = curl::easy_init();
  // defer curl::easy_cleanup(conn);
  // curl::easy_setopt(conn, curl::CURLOPT_URL, url);
  // curl::easy_setopt(conn, curl::CURLOPT_FOLLOWLOCATION);
  char[8192] buffer;
  ArenaAllocator arena;
  arena.init(&buffer);
  TrackingAllocator alloc;
  alloc.init(&arena);
  HttpClient client;
  client.init(&alloc)!;
  defer client.free();
  for(int i = 0; i < 10; i++) {
    arena.reset(0);
    io::printfn("Allocated: %d", alloc.total_allocated());
    HttpResponse* response = client.get_sync(url)!;
  }
  // io::printn("=== HEADERS ===");
  // io::printn(response.headers);
  // io::printn("=== RESPONSE ===");
  // io::printn(response.body.str_view());
}

fn int main(String[] args)
{
  if(catch excuse = get("https://jsonplaceholder.typicode.com/posts/1")) {
    io::printfn("Could not perform call: %s", excuse);
  }
  return 0;
}

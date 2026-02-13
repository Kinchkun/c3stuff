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
  char[8064] buffer;
  ArenaAllocator arena;
  arena.init(&buffer);

  HttpClient client;
  client.init()!;
  defer client.close();

  HttpResponse response;
  response.init(&arena);

  client.request_sync(GET, "https://jsonplaceholder.typicode.com/posts/1", null, &response)!;
  io::printn(response);

  String json = `{"title": "MyTitle", "body": "MyBody", "userId": 1}`;
  client.request_sync(POST, "https://jsonplaceholder.typicode.com/posts", json, &response)!;
  io::printn(response);
}


fn int main(String[] args)
{
  if(catch excuse = get("https://jsonplaceholder.typicode.com/posts/1")) {
    io::printfn("Could not perform call: %s", excuse);
  }
  return 0;
}

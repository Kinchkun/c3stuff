// Maven Dependency Manager
// Goals:
// - Search maven.central for artifacts
// - Add found dependencies to libs.version.toml's

import std::io;
import curl;
import hc;
import yyjson;

bitstruct CurlHFlags : uint {
  bool header;
}


macro log(String format, args...) {
  io::printf("[%s:%d]: ", $$FILE, $$LINE);
  io::printfn(format, ...args);
}


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

  yyjson::Doc doc;

  // GET request
  HttpRequest get_req = hc::get("https://jsonplaceholder.typicode.com/posts/1");
  client.request_sync(&get_req, &response)!;
  yyjson::Val root = yyjson::parse_bytes(&response.body, &doc)!;
  defer yyjson::doc_free(doc);
  io::printn("=== GET Response ===");
  io::printn(root.pretty());

  // POST request with JSON body and Content-Type header
  HttpRequest post_req = hc::post("https://jsonplaceholder.typicode.com/posts");
  post_req.set_header("Content-Type: application/json");
  String json = `{"title": "MyTitle", "body": "MyBody", "userId": 1}`;
  io::ByteReader body;
  body.init(json);
  post_req.set_body(&body);
  defer post_req.free();

  client.request_sync(&post_req, &response)!;
  yyjson::Doc doc2;
  yyjson::Val root2 = yyjson::parse_bytes(&response.body, &doc2)!;
  defer yyjson::doc_free(doc2);
  io::printn("=== POST Response ===");
  io::printn(root2.pretty());
}


fn int main(String[] args)
{
  if(catch excuse = get("https://jsonplaceholder.typicode.com/posts/1")) {
    io::printfn("Could not perform call: %s", excuse);
  }
  return 0;
}

// Maven Dependency Manager
// Goals:
// - Search maven.central for artifacts
// - Add found dependencies to libs.version.toml's

import std::io;
import std::core::mem;
import std::core::mem::allocator;
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


fn void? fetch_all_posts() {
  // Use heap for JSON parsing since it can be large
  DynamicArenaAllocator arena;
  arena.init(mem, 64 * 1024);  // 64KB pages, heap-backed
  defer arena.free();

  HttpClient client;
  client.init()!;
  defer client.close();

  HttpResponse response;
  response.init(&arena);

  // First, fetch the list of posts
  log("Fetching posts list...");
  HttpRequest list_req = hc::get("https://jsonplaceholder.typicode.com/posts");
  client.request_sync(&list_req, &response)!;

  yyjson::Val posts = yyjson::parse_bytes(&response.body, &arena)!;

  usz arr_len = yyjson::arr_size(posts);
  log("Found %d posts, creating requests for first 10...", arr_len);

  // Limit to first 10 posts for demo
  usz limit = arr_len < 10 ? arr_len : 10;

  // Allocate requests array from arena
  HttpRequest[10] requests;
  DString[10] urls;  // Keep URLs alive

  for (usz i = 0; i < limit; i++) {
    yyjson::Val post = yyjson::arr_get(posts, i);
    ulong id = yyjson::get_uint(yyjson::obj_get(post, "id"));

    // Build URL for this post
    urls[i].init(&arena);
    urls[i].appendf("https://jsonplaceholder.typicode.com/posts/%d", id);

    requests[i] = hc::get(urls[i].str_view());
  }

  // Don't reset arena - URLs are still allocated there

  // Execute all requests in parallel
  log("Executing %d requests in parallel...", limit);

  client.request_multi(
    requests[:limit],
    &arena,
    fn void(HttpRequest* req, HttpResponse* resp) {
      io::printfn("\n=== Response from: %s ===", req.url);
      yyjson::Val json = yyjson::parse((String)resp.body.array_view(), mem)!!;
      ZString title = yyjson::get_str(yyjson::obj_get(json, "title"));
      io::printfn("Title: %s", title);
    }
  )!;

  log("All requests completed!");
}


fn int main(String[] args)
{
  if(catch excuse = fetch_all_posts()) {
    io::printfn("Could not perform call: %s", excuse);
  }
  return 0;
}

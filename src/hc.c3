import std::io;
import curl;

faultdef INIT_ERROR, CALL_ERROR;

fn void global_init() @init {
  io::printn("HC WITH CURL BACKEND INIT");
  curl::global_init(1);
  Version_info_data* version_info = curl::version_info(curl::CURLversion.CURLVERSION_LAST);
  io::printfn("CURL VERSION: %s", (ZString)version_info.version);
}

fn void global_finalizer() @finalizer {
  io::printn("HC GLOBAL DESTROY");
  curl::global_cleanup();
}

enum HttpCallOptions : uint(curl::CURLoption option) {
  FOLLOW_LOCATION = curl::CURLOPT_FOLLOWLOCATION
}


struct HttpClient {
  Curl* handle;
  Allocator allocator;
  HttpResponse response;
}

struct HttpResponse {
  DString headers;
  ByteWriter body;
}


fn void HttpResponse.init(&self, Allocator alloc) {
  self.headers.init(alloc);
  self.body.init(alloc);
}

fn void? HttpResponse.free(&self) {
  self.body.destroy()!;
  self.headers.clear();
}

fn void? HttpClient.init(HttpClient* self, Allocator alloc) @private {
  self.handle = curl::easy_init();
  if(self.handle == null) {
    return INIT_ERROR~;
  }
  self.allocator = alloc;
  curl::easy_setopt(
    self.handle, 
    curl::CURLOPT_WRITEFUNCTION, 
    &write_call_back);
  curl::easy_setopt(
    self.handle, 
    curl::CURLOPT_WRITEDATA, 
    &self.response);
  curl::easy_setopt(
    self.handle, 
    curl::CURLOPT_HEADERFUNCTION, 
    &header_call_cack);
  curl::easy_setopt(
    self.handle, 
    curl::CURLOPT_HEADERDATA, 
    &self.response);
}

fn void HttpClient.set(HttpClient* self, HttpCallOptions options) {
  curl::easy_setopt(
    self.handle,
    options.option
  );
}

fn HttpResponse*? HttpClient.get_sync(
  HttpClient* self,
  String url) 
{
  curl::easy_setopt(
    self.handle,
    curl::CURLOPT_URL,
    url);

  self.response.free()!;

  HttpResponse response;
  self.response = response;
  self.response.init(self.allocator);


  curl::CURLcode result = curl::easy_perform(self.handle);
  if(result != curl::CURLcode.CURLE_OK) {
    io::printfn("Error occurred '%s'", result);
    return CALL_ERROR~;
  }
  return &self.response;
}

fn void HttpClient.free(HttpClient* self) {
  curl::easy_cleanup(self.handle);
  if(catch ex = self.response.free()) {
    io::printfn("Error freeing response: %s", ex);
  };
}


fn usz header_call_cack(
  ZString content,
  usz size,
  usz num_items,
  HttpResponse* response
) @private {
  String text = (String)content[:num_items];
  response.headers.append(text);
  return size * num_items;
}

fn usz write_call_back(
  char* content, 
  usz size, 
  usz num_items,
  HttpResponse* response
) @private {
  if(catch ex = response.body.write(content[:num_items])) {
    io::printfn("Could not write all bytes: %s", ex);
    return 0;
  }
  return size * num_items;
}

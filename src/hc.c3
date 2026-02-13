import std::io;
import curl;

faultdef INIT_ERROR, CALL_ERROR;

fn void global_init() @init {
  curl::global_init(1);
  Version_info_data* version_info = curl::version_info(curl::CURLversion.CURLVERSION_LAST);
  io::printfn("CURL VERSION: %s", (ZString)version_info.version);
}

fn void global_finalizer() @finalizer {
  curl::global_cleanup();
}

enum HttpCallOptions : uint(curl::CURLoption option) {
  FOLLOW_LOCATION = curl::CURLOPT_FOLLOWLOCATION
}

enum HttpMethod : char(ZString value) {
  GET = "GET",
  POST = "POST",
  PUT = "PUT",
  DELETE = "DELETE",
  PATCH = "PATCH",
  HEAD = "HEAD",
  OPTIONS = "OPTIONS"
}


struct HttpClient {
  Curl* handle;
}

struct HttpResponse (Printable) {
  Allocator allocator;
  DString headers;
  ByteWriter body;
}

fn usz? HttpResponse.to_format(&self, Formatter* f) @dynamic {
  usz n = f.print(self.headers.str_view())!;
  n += f.print(self.body.str_view())!;
  return n;
}

fn void HttpResponse.init(&self, Allocator alloc) {
  self.allocator = alloc;
  self.headers.init(alloc);
  self.body.init(alloc);
}

fn void HttpResponse.reset(&self) {
  // Just reinitialize - caller is responsible for resetting the arena/allocator
  // This allows bump allocator to reuse memory efficiently
  self.headers = {};
  self.body = {};
  self.headers.init(self.allocator);
  self.body.init(self.allocator);
}

fn void HttpResponse.free(&self) {
  // Free in reverse allocation order
  if (catch err = self.body.destroy()) {
    io::printfn("Error destroying body: %s", err);
  }
  self.headers.free();
}

fn void? HttpClient.init(HttpClient* self) {
  self.handle = curl::easy_init();
  if (self.handle == null) {
    return INIT_ERROR~;
  }
  curl::easy_setopt(
    self.handle,
    curl::CURLOPT_WRITEFUNCTION,
    &write_call_back);
  curl::easy_setopt(
    self.handle,
    curl::CURLOPT_HEADERFUNCTION,
    &header_call_cack);
}

fn void HttpClient.set(HttpClient* self, HttpCallOptions options) {
  curl::easy_setopt(
    self.handle,
    options.option
  );
}

macro void? HttpClient.request_sync(
  HttpClient* self,
  HttpMethod method,
  String url,
  body,
  HttpResponse* response)
{
  var $Type = $typeof(body);
  $if $Type.typeid == String.typeid:
    io::ByteReader reader;
    reader.init(body);
    return self.request_sync_stream(method, url, &reader, response);
  $else
    $if $Type.typeid == void*.typeid:
      return self.request_sync_stream(method, url, null, response);
    $else
      return self.request_sync_stream(method, url, body, response);
    $endif
  $endif
}

fn void? HttpClient.request_sync_stream(
  HttpClient* self,
  HttpMethod method,
  String url,
  InStream body,
  HttpResponse* response) @private
{
  response.reset();

  curl::easy_setopt(self.handle, curl::CURLOPT_CUSTOMREQUEST, method.value);
  curl::easy_setopt(self.handle, curl::CURLOPT_URL, url);
  curl::easy_setopt(self.handle, curl::CURLOPT_WRITEDATA, response);
  curl::easy_setopt(self.handle, curl::CURLOPT_HEADERDATA, response);

  // Set up request body if provided
  if (body) {
    curl::easy_setopt(self.handle, curl::CURLOPT_POST, 1);
    curl::easy_setopt(self.handle, curl::CURLOPT_READFUNCTION, &read_call_back);
    curl::easy_setopt(self.handle, curl::CURLOPT_READDATA, &body);
  } else {
    curl::easy_setopt(self.handle, curl::CURLOPT_POST, 0);
    curl::easy_setopt(self.handle, curl::CURLOPT_READDATA, null);
  }

  curl::CURLcode result = curl::easy_perform(self.handle);
  if (result != curl::CURLcode.CURLE_OK) {
    io::printfn("Error occurred '%s'", result);
    return CALL_ERROR~;
  }
}

fn void HttpClient.close(HttpClient* self) {
  curl::easy_cleanup(self.handle);
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
  if (catch err = response.body.write(content[:num_items])) {
    io::printfn("Could not write body: %s", err);
    return 0;
  }
  return size * num_items;
}

fn usz read_call_back(
  char* buffer,
  usz size,
  usz num_items,
  InStream* body
) @private {
  usz bytes_read = (*body).read(buffer[:size * num_items]) ?? 0;
  return bytes_read;
}

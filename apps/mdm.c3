// Maven Dependency Manager
// Goals:
// - Search maven.central for artifacts
// - Add found dependencies to libs.version.toml's

import std::io;

fn void get(String url) {
	io::printn(url);
}


fn int main(String[] args)
{
  get("https://google.com");
	io::printn("MDM Version 0.1.0");
	return 0;
}

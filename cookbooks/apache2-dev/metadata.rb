name             "apache2-dev"
maintainer       "Gennadiy Filatov"
maintainer_email "gfilatov@cpan.org"
license          "MIT"
description      "Installs apache2-dev"
long_description IO.read(File.join(File.dirname(__FILE__), "README.md"))
version          "1.0.0"

recipe "apache2-dev", "Installs apache2-dev package"

%w[debian].each do |os|
  supports os
end


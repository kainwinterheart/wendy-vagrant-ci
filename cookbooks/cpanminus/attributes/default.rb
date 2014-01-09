default.cpanminus.bootstrap.packages = %w[ curl ca-certificates libperl-dev ]

case platform 
    when 'centos'
        default.cpanminus.bootstrap.packages << 'perl-devel'
end


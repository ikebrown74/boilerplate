class gunicorn::instance($venv,
                          $src,
                          $ensure=present,
                          $django=false,
                          $version=undef,
                          $workers=1,
                          $timeout_seconds=30) {

  $rundir = Gunicorn::init::rundir
  $logdir = Gunicorn::init::logdir
  $owner = Gunicorn::init::owner
  $group = Gunicorn::init::group

  $initscript = "/etc/init.d/gunicorn-${name}"
  $pidfile = "$rundir/$name.pid"
  $socket = "unix:$rundir/$name.sock"
  $logfile = "$logdir/$name.log"

  $gunicorn_package = $version ? {
    undef => "gunicorn",
    default => "gunicorn==${version}",
  }

  if $is_present {
    python::pip::install {
      "$gunicorn_package in $venv":
        package => $gunicorn_package,
        ensure => $ensure,
        venv => $venv,
        owner => $owner,
        group => $group,
        require => Python::Venv::Isolate[$venv],
        before => File[$initscript];

      # for --name support in gunicorn:
      "setproctitle in $venv":
        package => "setproctitle",
        ensure => $ensure,
        venv => $venv,
        owner => $owner,
        group => $group,
        require => Python::Venv::Isolate[$venv],
        before => File[$initscript];
    }
  }

  $init_template = $::operatingsystem ? {
    /(?i)centos|fedora|redhat/ => "python/gunicorn.rhel.init.erb",
    default => "python/gunicorn.deb.init.erb",
  }

  file { $initscript:
    ensure => $ensure,
    content => template($init_template),
    mode => 744,
    require => File["/etc/logrotate.d/gunicorn-${name}"],
  }

  file { "/etc/logrotate.d/gunicorn-${name}":
    ensure => $ensure,
    content => template("python/gunicorn.logrotate.erb"),
  }

  service { "gunicorn-${name}":
    ensure => $is_present,
    enable => $is_present,
    hasstatus => $is_present,
    hasrestart => $is_present,
    subscribe => $ensure ? {
      'present' => File[$initscript],
      default => undef,
    },
    require => $ensure ? {
      'present' => File[$initscript],
      default => undef,
    },
    before => $ensure ? {
      'absent' => File[$initscript],
      default => undef,
    },
  }
}

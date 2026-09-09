Name:           pomodoro_app
Version:        1.0.0
Release:        1%{?dist}
Summary:        A Material Design 3 Pomodoro timer app built with Flutter.

License:        MIT
URL:            https://example.com

Source0:        pomodoro_app-1.0.0.tar.gz
Source1:        pomodoro_app.desktop

BuildArch:      x86_64

%define debug_package %{nil}

%description
A Material Design 3 Pomodoro timer app built with Flutter.
Features customizable work/break durations, ambient sounds, todo list, and focus statistics.

%prep
%autosetup -c -n %{name}-%{version}

%build
# Pre-built Flutter app, nothing to build.

%install
mkdir -p %{buildroot}/opt/%{name}
cp -a * %{buildroot}/opt/%{name}/

mkdir -p %{buildroot}/usr/share/applications
install -m 644 %{SOURCE1} %{buildroot}/usr/share/applications/%{name}.desktop

%files
/opt/%{name}/
/usr/share/applications/%{name}.desktop

%changelog
* Wed Sep 09 2026 yjlc <yjlc@example.com> - 1.0.0-1
- Initial RPM release.

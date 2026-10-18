Name:           pomodoro_app
Version:        0.0.1
Release:        1%{?dist}
Summary:        A Material Design 3 Pomodoro timer app built with Flutter.

License:        MIT
URL:            https://github.com/yjlc-pc/pomodoro-app

Source0:        pomodoro_app-%{version}.tar.gz
Source1:        pomodoro_app.desktop

BuildArch:      x86_64

%define debug_package %{nil}

%description
A Material Design 3 Pomodoro timer app built with Flutter.
Features customizable work/break durations, ambient sounds, a todo list with
sub-steps / priority / notes, and focus statistics.

%prep
# No -c / -n here. The tarball already carries its own top-level directory
# (%{name}-%{version}), which autosetup cds into on its own. Asking for a dir
# it also creates (-c) nests a second copy, so `cp -a *` then installed
# /opt/pomodoro_app/%{name}-%{version}/%{name}-%{version}/... and broke the
# Exec= path in the .desktop file.
%autosetup

%build
# Pre-built Flutter app, nothing to build.

%install
mkdir -p %{buildroot}/opt/%{name}
# Copy out of the extracted source directory by explicit path rather than a bare
# `*`, so the result does not depend on where %prep's symlink chain happened to
# leave the cwd. A bare `*` silently installed
# /opt/pomodoro_app/%{name}-%{version}/... one level too deep, which breaks the
# Exec= path in the .desktop file.
cd %{_builddir}/%{name}-%{version}
cp -a * %{buildroot}/opt/%{name}/

mkdir -p %{buildroot}/usr/share/applications
install -m 644 %{SOURCE1} %{buildroot}/usr/share/applications/%{name}.desktop

%files
/opt/%{name}/
/usr/share/applications/%{name}.desktop

%changelog
* Sun Oct 18 2026 yjlc <yjlc.18979607766@outlook.com> - 0.0.1-1
- Todos gain sub-steps, priority and notes, plus a detail sheet.
- The countdown ring now consumes rather than accumulates, and is colour-coded
  per phase.
- Ticking a todo animates (fill, then a drawn tick).
- Text colours are pinned to Material 3 colour roles.
- Website and packager contact filled in.
* Wed Sep 09 2026 yjlc <yjlc@example.com> - 1.0.0-1
- Initial RPM release.
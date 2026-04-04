# p2p
1. ```git clone https://github.com/flutter/flutter.git -b stable```
on GitHub code space: (بعد تحميل فلاتر)
1. ```echo 'export PATH="$PATH:/workspaces/p2p/flutter/bin"' >> ~/.bashrc``` -> ```source ~/.bashrc```
2. ```flutter analyze lib```
3. ```flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0```
4. ```dart run build_runner build --delete-conflicting-outputs```

brensch@Schbox:~/schlift$ ~/android-sdk/platform-tools/adb connect
 192.168.1.20:40203
failed to connect to 192.168.1.20:40203
brensch@Schbox:~/schlift$ ~/android-sdk/platform-tools/adb pair 192.168.1.20:36073
Enter pairing code: 100632
Successfully paired to 192.168.1.20:36073 [guid=adb-59221WRBNW40L7-abjBLe]
brensch@Schbox:~/schlift$ ~/android-sdk/platform-tools/adb connect 192.168.1.20:44819
connected to 192.168.1.20:44819
brensch@Schbox:~/schlift$ WEAR_SERIAL=192.168.1.20:44819 make run-
wear-debug 


also go into watch settings
turn on wireless debugging
add pair new device
then use the port in that with the pair command

then use the port in the main bit fo the debugging menu for the connect command

# R8 full mode (AGP 8 default) strips the no-arg constructors of Room's
# generated *_Impl classes, which Room reflectively instantiates by name
# (<DbClass>_Impl). WorkManager auto-inits via androidx.startup on app launch
# and hits this on WorkDatabase_Impl -> NoSuchMethodException, crashing the
# process before Flutter attaches. Keep the class names + no-arg constructors.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }

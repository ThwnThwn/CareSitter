import 'package:flutter/material.dart';

/// Spring-like curve giống Grab: ease-out cực nhanh, dừng mềm
const staggeredSpring = Cubic(0.16, 1.0, 0.30, 1.0);

/// Duration tổng cho mỗi item: đủ nhanh để không cảm thấy chờ
const staggeredItemDuration = Duration(milliseconds: 180);

// Firebase Cloud Messaging の Service Worker（リマインド通知。仕様書 5.2）
// サイトのルートに置く。通知の表示と、押したときに開く URL は、
// 送信側（Cloud Functions）の notification・webpush.fcmOptions.link で決まる。

// FlutterFire が読む Firebase JS SDK の版にそろえる
// （firebase_core_web の supportedFirebaseJsSdkVersion）
const FIREBASE_JS_VERSION = '13.1.0';

importScripts(
  `https://www.gstatic.com/firebasejs/${FIREBASE_JS_VERSION}/firebase-app-compat.js`,
);
importScripts(
  `https://www.gstatic.com/firebasejs/${FIREBASE_JS_VERSION}/firebase-messaging-compat.js`,
);

// lib/firebase_options.dart の Web の値と同じ
firebase.initializeApp({
  apiKey: 'AIzaSyBiKCGRHpE1nR3mgEHfov7rtg2Wm8BZuKE',
  appId: '1:809122136778:web:d667ab687d6755b7dd6a33',
  messagingSenderId: '809122136778',
  projectId: 'oshiashi-test',
  authDomain: 'oshiashi-test.firebaseapp.com',
  storageBucket: 'oshiashi-test.firebasestorage.app',
  measurementId: 'G-HDQH9CC99N',
});

firebase.messaging();
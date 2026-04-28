importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyC4kKB1znluYwIxrg2cz0UKYD2EaJdFU5Y",
  authDomain: "household-towing-system.firebaseapp.com",
  projectId: "household-towing-system",
  storageBucket: "household-towing-system.firebasestorage.app",
  messagingSenderId: "318653580866",
  appId: "1:318653580866:web:2e882bc1061cd8d6fe4fdb"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

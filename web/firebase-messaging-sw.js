// Firebase Messaging Service Worker for Web Push Notifications
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD_Um0UkiMw3evn6Sq8n66b4t1Ojxvp2L4',
  appId: '1:584952056517:web:9c58d1dd3ed79cd02afeac',
  messagingSenderId: '584952056517',
  projectId: 'sofvo-19d84',
  authDomain: 'sofvo.com',
  storageBucket: 'sofvo-19d84.firebasestorage.app',
  measurementId: 'G-SGB6RFNZVV',
});

const messaging = firebase.messaging();

// バックグラウンドメッセージのハンドリング
messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification;
  if (!notification) return;

  const notificationTitle = notification.title || 'Sofvo';
  const notificationOptions = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// 通知クリック時のハンドリング
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // 既に開いているウィンドウがあればフォーカス
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // なければ新しいウィンドウを開く
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});

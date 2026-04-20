// Minimal Firebase Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js');

// This is required for the service worker to be recognized by Flutter
// You don't necessarily need to initialize it here if you don't use background notifications on web yet
// but having the file prevents registration errors.

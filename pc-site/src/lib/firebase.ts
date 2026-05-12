import { initializeApp, getApps } from "firebase/app";
import { getFirestore, initializeFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyD_Um0UkiMw3evn6Sq8n66b4t1Ojxvp2L4",
  authDomain: "sofvo.com",
  projectId: "sofvo-19d84",
  storageBucket: "sofvo-19d84.firebasestorage.app",
  messagingSenderId: "584952056517",
  appId: "1:584952056517:web:9c58d1dd3ed79cd02afeac",
  measurementId: "G-SGB6RFNZVV",
};

const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];

let db: ReturnType<typeof getFirestore>;
try {
  db = initializeFirestore(app, {
    experimentalAutoDetectLongPolling: true,
  });
} catch {
  db = getFirestore(app);
}
export { db };
export const auth = getAuth(app);
export const storage = getStorage(app);

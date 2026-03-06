"use client";

import { createContext, useContext, useEffect, useState, ReactNode } from "react";
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  GoogleAuthProvider,
  OAuthProvider,
  signInWithPopup,
  User,
} from "firebase/auth";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { auth, db } from "@/lib/firebase";

export interface UserProfile {
  uid: string;
  nickname: string;
  email: string;
  avatarUrl?: string;
  bio?: string;
  searchId?: string;
  experience?: string;
  area?: string;
  gender?: string;
  totalPoints?: number;
  followersCount?: number;
  followingCount?: number;
  stats?: {
    tournamentsPlayed?: number;
    championships?: number;
  };
}

interface AuthContextType {
  user: User | null;
  profile: UserProfile | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, nickname: string) => Promise<void>;
  signInWithGoogle: () => Promise<void>;
  signInWithApple: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (firebaseUser) => {
      setUser(firebaseUser);
      if (firebaseUser) {
        const snap = await getDoc(doc(db, "users", firebaseUser.uid));
        if (snap.exists()) {
          setProfile({ uid: firebaseUser.uid, ...snap.data() } as UserProfile);
        }
      } else {
        setProfile(null);
      }
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const signIn = async (email: string, password: string) => {
    await signInWithEmailAndPassword(auth, email, password);
  };

  const signUp = async (email: string, password: string, nickname: string) => {
    const cred = await createUserWithEmailAndPassword(auth, email, password);
    await setDoc(doc(db, "users", cred.user.uid), {
      nickname,
      email,
      totalPoints: 0,
      followersCount: 0,
      followingCount: 0,
      profileCompleted: false,
      createdAt: new Date(),
    });
  };

  const signInWithGoogle = async () => {
    const provider = new GoogleAuthProvider();
    const cred = await signInWithPopup(auth, provider);
    const snap = await getDoc(doc(db, "users", cred.user.uid));
    if (!snap.exists()) {
      await setDoc(doc(db, "users", cred.user.uid), {
        nickname: cred.user.displayName || "ユーザー",
        email: cred.user.email,
        avatarUrl: cred.user.photoURL || "",
        totalPoints: 0,
        followersCount: 0,
        followingCount: 0,
        profileCompleted: false,
        createdAt: new Date(),
      });
    }
  };

  const signInWithApple = async () => {
    const provider = new OAuthProvider("apple.com");
    provider.addScope("email");
    provider.addScope("name");
    const cred = await signInWithPopup(auth, provider);
    const snap = await getDoc(doc(db, "users", cred.user.uid));
    if (!snap.exists()) {
      await setDoc(doc(db, "users", cred.user.uid), {
        nickname: cred.user.displayName || "ユーザー",
        email: cred.user.email,
        avatarUrl: cred.user.photoURL || "",
        totalPoints: 0,
        followersCount: 0,
        followingCount: 0,
        profileCompleted: false,
        createdAt: new Date(),
      });
    }
  };

  const signOut = async () => {
    await firebaseSignOut(auth);
    setProfile(null);
  };

  return (
    <AuthContext.Provider
      value={{ user, profile, loading, signIn, signUp, signInWithGoogle, signInWithApple, signOut }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}

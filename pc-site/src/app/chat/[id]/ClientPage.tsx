"use client";

import { useEffect, useState, useRef, useCallback } from "react";
import { useParams } from "next/navigation";
import {
  collection,
  query,
  orderBy,
  onSnapshot,
  addDoc,
  doc,
  getDoc,
  updateDoc,
  Timestamp,
  serverTimestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { ChatRoom, ChatMessage } from "@/types/firestore";
import Link from "next/link";

/** Format message time as HH:MM */
function formatTime(ts: unknown): string {
  if (!ts) return "";
  let date: Date;
  if (ts instanceof Timestamp) {
    date = ts.toDate();
  } else if (ts instanceof Date) {
    date = ts;
  } else if (typeof ts === "object" && ts !== null && "seconds" in ts) {
    date = new Date((ts as { seconds: number }).seconds * 1000);
  } else {
    return "";
  }
  return date.toLocaleTimeString("ja-JP", {
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Relative time helper */
function relativeTime(ts: unknown): string {
  if (!ts) return "";
  let date: Date;
  if (ts instanceof Timestamp) {
    date = ts.toDate();
  } else if (ts instanceof Date) {
    date = ts;
  } else if (typeof ts === "object" && ts !== null && "seconds" in ts) {
    date = new Date((ts as { seconds: number }).seconds * 1000);
  } else {
    return "";
  }
  const now = Date.now();
  const diff = Math.floor((now - date.getTime()) / 1000);
  if (diff < 60) return "たった今";
  if (diff < 3600) return `${Math.floor(diff / 60)}分前`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}時間前`;
  if (diff < 2592000) return `${Math.floor(diff / 86400)}日前`;
  return date.toLocaleDateString("ja-JP");
}

export default function ChatConversationPage() {
  const params = useParams<{ id: string }>();
  const chatId = (params?.id ?? "") as string;
  const { user, profile, loading: authLoading } = useAuth();
  const [chatRoom, setChatRoom] = useState<ChatRoom | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [messageText, setMessageText] = useState("");
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);

  // Scroll to bottom
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, []);

  // Load chat room metadata
  useEffect(() => {
    async function loadChat() {
      const snap = await getDoc(doc(db, "chats", chatId));
      if (snap.exists()) {
        setChatRoom({ id: snap.id, ...snap.data() } as ChatRoom);
      }
      setLoading(false);
    }
    loadChat();
  }, [chatId]);

  // Real-time messages
  useEffect(() => {
    const q = query(
      collection(db, "chats", chatId, "messages"),
      orderBy("createdAt", "asc")
    );
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as ChatMessage)
      );
      setMessages(list);
      // Scroll after messages update
      setTimeout(scrollToBottom, 100);
    });
    return () => unsub();
  }, [chatId, scrollToBottom]);

  // Update lastRead when viewing
  useEffect(() => {
    if (!user || !chatRoom) return;
    const chatRef = doc(db, "chats", chatId);
    updateDoc(chatRef, {
      [`lastRead.${user.uid}`]: serverTimestamp(),
    }).catch(() => {
      // Silently ignore errors (e.g. permission)
    });
  }, [user, chatRoom, chatId, messages.length]);

  // Derive display name
  const chatName = chatRoom
    ? chatRoom.type === "dm"
      ? (() => {
          const otherUid = chatRoom.members.find((m) => m !== user?.uid);
          return otherUid && chatRoom.memberNames[otherUid]
            ? chatRoom.memberNames[otherUid]
            : "DM";
        })()
      : chatRoom.name || "グループチャット"
    : "";

  const memberCount = chatRoom?.members.length ?? 0;

  // Send message
  const handleSend = useCallback(async () => {
    if (!user || !profile || !messageText.trim() || sending) return;
    setSending(true);
    try {
      const text = messageText.trim();
      setMessageText("");

      // Add message to subcollection
      await addDoc(collection(db, "chats", chatId, "messages"), {
        senderId: user.uid,
        text,
        createdAt: serverTimestamp(),
      });

      // Update chat metadata
      await updateDoc(doc(db, "chats", chatId), {
        lastMessage: text,
        lastMessageAt: serverTimestamp(),
        [`lastRead.${user.uid}`]: serverTimestamp(),
      });
    } finally {
      setSending(false);
    }
  }, [user, profile, messageText, sending, chatId]);

  // Sender display name
  const senderName = (senderId: string): string => {
    if (!chatRoom) return "";
    return chatRoom.memberNames[senderId] || "Unknown";
  };

  // Loading
  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Not logged in
  if (!user || !profile) {
    return (
      <div className="p-8 max-w-[800px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <svg className="w-12 h-12 mx-auto text-muted mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
          </svg>
          <h3 className="text-lg font-bold text-foreground mb-2">
            ログインが必要です
          </h3>
          <p className="text-sm text-muted mb-4">
            チャットを利用するにはログインしてください
          </p>
          <Link
            href="/login"
            className="inline-block px-6 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            ログイン
          </Link>
        </div>
      </div>
    );
  }

  // Chat not found
  if (!chatRoom) {
    return (
      <div className="p-8 max-w-[800px] mx-auto">
        <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
          <svg className="w-12 h-12 mx-auto text-muted mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
          </svg>
          <h3 className="text-lg font-bold text-foreground mb-2">
            チャットが見つかりません
          </h3>
          <Link
            href="/chat"
            className="text-sm text-primary hover:underline"
          >
            チャット一覧に戻る
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-[calc(100vh-2rem)] max-w-[800px] mx-auto p-4 pt-8">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-muted mb-4">
        <Link href="/chat" className="hover:text-primary transition-colors">
          チャット
        </Link>
        <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
        </svg>
        <span className="text-foreground truncate">{chatName}</span>
      </div>

      {/* Chat Header */}
      <div className="bg-white rounded-xl border border-gray-200 px-5 py-4 mb-4 flex items-center gap-4">
        <Link
          href="/chat"
          className="flex items-center justify-center w-8 h-8 rounded-lg hover:bg-gray-100 transition-colors flex-shrink-0"
        >
          <svg className="w-5 h-5 text-muted" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
          </svg>
        </Link>
        <div
          className={`w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 ${
            chatRoom.type === "dm"
              ? "bg-primary/10 text-primary"
              : "bg-accent/10 text-accent"
          }`}
        >
          {chatRoom.type === "dm" ? (
            chatName.charAt(0) || "?"
          ) : (
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
            </svg>
          )}
        </div>
        <div className="flex-1 min-w-0">
          <h2 className="text-base font-bold text-foreground truncate">
            {chatName}
          </h2>
          <p className="text-xs text-muted">
            {memberCount}人のメンバー
          </p>
        </div>
      </div>

      {/* Messages */}
      <div
        ref={messagesContainerRef}
        className="flex-1 overflow-y-auto bg-white rounded-xl border border-gray-200 p-5"
      >
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <svg className="w-10 h-10 mx-auto text-muted mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z" />
              </svg>
              <p className="text-sm text-muted">
                まだメッセージはありません
              </p>
              <p className="text-xs text-muted mt-1">
                最初のメッセージを送ってみましょう
              </p>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            {messages.map((msg) => {
              const isMe = msg.senderId === user.uid;
              return (
                <div
                  key={msg.id}
                  className={`flex ${isMe ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-[70%] ${
                      isMe ? "items-end" : "items-start"
                    }`}
                  >
                    {/* Sender name (not for current user) */}
                    {!isMe && (
                      <p className="text-xs text-muted mb-1 ml-1">
                        {senderName(msg.senderId)}
                      </p>
                    )}
                    <div
                      className={`px-4 py-2.5 rounded-2xl ${
                        isMe
                          ? "bg-primary text-white rounded-br-md"
                          : "bg-gray-100 text-foreground rounded-bl-md"
                      }`}
                    >
                      <p className="text-sm whitespace-pre-wrap break-words">
                        {msg.text}
                      </p>
                      {/* Image */}
                      {msg.imageUrl && (
                        <img
                          src={msg.imageUrl}
                          alt=""
                          className="mt-2 rounded-lg max-h-60 max-w-full object-cover"
                        />
                      )}
                    </div>
                    <p
                      className={`text-xs text-muted mt-1 ${
                        isMe ? "text-right mr-1" : "ml-1"
                      }`}
                    >
                      {formatTime(msg.createdAt)}
                    </p>
                  </div>
                </div>
              );
            })}
            <div ref={messagesEndRef} />
          </div>
        )}
      </div>

      {/* Message Input */}
      <div className="bg-white rounded-xl border border-gray-200 p-3 mt-4 flex items-end gap-3">
        <textarea
          value={messageText}
          onChange={(e) => setMessageText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              handleSend();
            }
          }}
          placeholder="メッセージを入力..."
          rows={1}
          className="flex-1 resize-none border border-gray-200 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:border-primary max-h-32"
          style={{ minHeight: "40px" }}
        />
        <button
          onClick={handleSend}
          disabled={!messageText.trim() || sending}
          className="px-5 py-2.5 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50 flex-shrink-0 flex items-center gap-2"
        >
          {sending ? (
            <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
          ) : (
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5" />
            </svg>
          )}
          送信
        </button>
      </div>
    </div>
  );
}

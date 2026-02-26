"use client";

import { useEffect, useState, useCallback } from "react";
import {
  collection,
  query,
  orderBy,
  limit,
  getDocs,
  addDoc,
  doc,
  getDoc,
  setDoc,
  deleteDoc,
  updateDoc,
  increment,
  onSnapshot,
  Timestamp,
} from "firebase/firestore";
import { db } from "@/lib/firebase";
import { useAuth } from "@/contexts/AuthContext";
import type { Post, PostComment, Notice } from "@/types/firestore";
import Link from "next/link";
import ImageLightbox from "@/components/ImageLightbox";

type Tab = "timeline" | "notices";

/** 相対時間を返す */
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

/** お知らせタイプに応じた左ボーダー色を返す */
function noticeBorderColor(type: string): string {
  switch (type) {
    case "update":
    case "アップデート":
      return "border-l-blue-500";
    case "event":
    case "イベント":
      return "border-l-green-500";
    case "important":
    case "重要":
      return "border-l-red-500";
    case "maintenance":
    case "メンテナンス":
      return "border-l-orange-500";
    default:
      return "border-l-primary";
  }
}

export default function FeedPage() {
  const { user, profile, loading: authLoading } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>("timeline");
  const [posts, setPosts] = useState<Post[]>([]);
  const [notices, setNotices] = useState<Notice[]>([]);
  const [likedMap, setLikedMap] = useState<Record<string, boolean>>({});
  const [expandedComments, setExpandedComments] = useState<Record<string, boolean>>({});
  const [commentsMap, setCommentsMap] = useState<Record<string, PostComment[]>>({});
  const [commentTexts, setCommentTexts] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [noticesLoading, setNoticesLoading] = useState(true);
  const [lightboxSrc, setLightboxSrc] = useState<string | null>(null);

  // New post form
  const [showPostForm, setShowPostForm] = useState(false);
  const [newPostText, setNewPostText] = useState("");
  const [newPostImage, setNewPostImage] = useState("");
  const [posting, setPosting] = useState(false);

  // Load posts
  useEffect(() => {
    async function loadPosts() {
      const q = query(
        collection(db, "posts"),
        orderBy("createdAt", "desc"),
        limit(50)
      );
      const snap = await getDocs(q);
      const list = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as Post)
      );
      setPosts(list);
      setLoading(false);

      // Check liked status for logged-in user
      if (user) {
        const likeChecks: Record<string, boolean> = {};
        await Promise.all(
          list.map(async (post) => {
            const likeSnap = await getDoc(
              doc(db, "posts", post.id, "likes", user.uid)
            );
            likeChecks[post.id] = likeSnap.exists();
          })
        );
        setLikedMap(likeChecks);
      }
    }
    loadPosts();
  }, [user]);

  // Load notices
  useEffect(() => {
    if (activeTab !== "notices") return;
    async function loadNotices() {
      setNoticesLoading(true);
      const q = query(
        collection(db, "notices"),
        orderBy("createdAt", "desc"),
        limit(50)
      );
      const snap = await getDocs(q);
      setNotices(
        snap.docs.map((d) => ({ id: d.id, ...d.data() } as Notice))
      );
      setNoticesLoading(false);
    }
    loadNotices();
  }, [activeTab]);

  // Toggle like
  const handleLike = useCallback(
    async (postId: string) => {
      if (!user) return;
      const liked = likedMap[postId];
      const likeRef = doc(db, "posts", postId, "likes", user.uid);
      const postRef = doc(db, "posts", postId);

      if (liked) {
        await deleteDoc(likeRef);
        await updateDoc(postRef, { likesCount: increment(-1) });
        setLikedMap((prev) => ({ ...prev, [postId]: false }));
        setPosts((prev) =>
          prev.map((p) =>
            p.id === postId ? { ...p, likesCount: Math.max(0, p.likesCount - 1) } : p
          )
        );
      } else {
        await setDoc(likeRef, { uid: user.uid, createdAt: Timestamp.now() });
        await updateDoc(postRef, { likesCount: increment(1) });
        setLikedMap((prev) => ({ ...prev, [postId]: true }));
        setPosts((prev) =>
          prev.map((p) =>
            p.id === postId ? { ...p, likesCount: p.likesCount + 1 } : p
          )
        );
      }
    },
    [user, likedMap]
  );

  // Toggle comments
  const toggleComments = useCallback(
    async (postId: string) => {
      const isOpen = expandedComments[postId];
      setExpandedComments((prev) => ({ ...prev, [postId]: !isOpen }));

      if (!isOpen && !commentsMap[postId]) {
        const q = query(
          collection(db, "posts", postId, "comments"),
          orderBy("createdAt", "asc")
        );
        const snap = await getDocs(q);
        setCommentsMap((prev) => ({
          ...prev,
          [postId]: snap.docs.map(
            (d) => ({ id: d.id, ...d.data() } as PostComment)
          ),
        }));
      }
    },
    [expandedComments, commentsMap]
  );

  // Post comment
  const handleComment = useCallback(
    async (postId: string) => {
      if (!user || !profile) return;
      const text = commentTexts[postId]?.trim();
      if (!text) return;

      const newComment: Omit<PostComment, "id"> = {
        userId: user.uid,
        userNickname: profile.nickname,
        userAvatarUrl: profile.avatarUrl || "",
        text,
        createdAt: Timestamp.now(),
      };

      const docRef = await addDoc(
        collection(db, "posts", postId, "comments"),
        newComment
      );
      await updateDoc(doc(db, "posts", postId), {
        commentsCount: increment(1),
      });

      setCommentsMap((prev) => ({
        ...prev,
        [postId]: [
          ...(prev[postId] || []),
          { id: docRef.id, ...newComment } as PostComment,
        ],
      }));
      setPosts((prev) =>
        prev.map((p) =>
          p.id === postId ? { ...p, commentsCount: p.commentsCount + 1 } : p
        )
      );
      setCommentTexts((prev) => ({ ...prev, [postId]: "" }));
    },
    [user, profile, commentTexts]
  );

  // Create post
  const handleCreatePost = useCallback(async () => {
    if (!user || !profile || !newPostText.trim()) return;
    setPosting(true);
    try {
      const postData: Omit<Post, "id"> = {
        userId: user.uid,
        userNickname: profile.nickname,
        userAvatarUrl: profile.avatarUrl || "",
        text: newPostText.trim(),
        images: newPostImage.trim() ? [newPostImage.trim()] : [],
        likesCount: 0,
        commentsCount: 0,
        createdAt: Timestamp.now(),
      };
      const docRef = await addDoc(collection(db, "posts"), postData);
      setPosts((prev) => [{ id: docRef.id, ...postData } as Post, ...prev]);
      setNewPostText("");
      setNewPostImage("");
      setShowPostForm(false);
    } finally {
      setPosting(false);
    }
  }, [user, profile, newPostText, newPostImage]);

  const tabs: { key: Tab; label: string; icon: React.ReactNode }[] = [
    {
      key: "timeline",
      label: "タイムライン",
      icon: (
        <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
        </svg>
      ),
    },
    {
      key: "notices",
      label: "お知らせ",
      icon: (
        <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
      ),
    },
  ];

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="max-w-[800px] mx-auto pb-12">
      {/* Header — Navy gradient banner */}
      <div className="bg-gradient-to-r from-[#1a2a5e] via-[#223370] to-[#2b3d8b] rounded-2xl px-8 py-7 mb-8 flex items-center justify-between shadow-lg">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-wide">フィード</h1>
          <p className="text-white/60 text-sm mt-1">みんなの最新情報をチェック</p>
        </div>
        {user && profile && (
          <button
            onClick={() => setShowPostForm(!showPostForm)}
            className="btn-accent px-5 py-2.5 bg-gradient-to-r from-amber-400 to-yellow-500 text-[#1a2a5e] rounded-xl text-sm font-bold hover:from-amber-300 hover:to-yellow-400 transition-all shadow-md hover:shadow-lg active:scale-95"
          >
            <span className="flex items-center gap-2">
              <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2.5} viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
              </svg>
              投稿する
            </span>
          </button>
        )}
      </div>

      {/* Tabs — Navy active style */}
      <div className="flex gap-1 bg-gray-100 rounded-xl p-1.5 mb-8 shadow-sm">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-1 py-2.5 text-sm font-semibold rounded-lg transition-all duration-200 flex items-center justify-center gap-2 ${
              activeTab === tab.key
                ? "bg-primary text-white shadow-md"
                : "text-muted hover:text-foreground hover:bg-white/60"
            }`}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      {/* Create Post Form — Richer styling with gradient top border */}
      {showPostForm && user && profile && (
        <div className="bg-white rounded-2xl border border-gray-200 overflow-hidden mb-8 shadow-sm">
          <div className="h-1 bg-gradient-to-r from-[#1a2a5e] via-[#3b5bdb] to-amber-400" />
          <div className="p-6">
            <div className="flex items-start gap-4">
              <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden ring-2 ring-primary/20">
                {profile.avatarUrl ? (
                  <img src={profile.avatarUrl} alt="" className="w-11 h-11 object-cover" />
                ) : (
                  profile.nickname?.charAt(0) || "U"
                )}
              </div>
              <div className="flex-1">
                <textarea
                  value={newPostText}
                  onChange={(e) => setNewPostText(e.target.value)}
                  placeholder="いまどうしてる?"
                  className="w-full border border-gray-200 rounded-xl p-4 text-sm text-foreground resize-none focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
                  rows={3}
                />
                <div className="flex items-center gap-2 mt-3">
                  <svg className="w-4 h-4 text-muted flex-shrink-0" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <input
                    type="text"
                    value={newPostImage}
                    onChange={(e) => setNewPostImage(e.target.value)}
                    placeholder="画像URL (任意)"
                    className="flex-1 border border-gray-200 rounded-lg px-3 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
                  />
                </div>
                <div className="flex justify-end mt-4 gap-2">
                  <button
                    onClick={() => setShowPostForm(false)}
                    className="px-4 py-2.5 text-sm text-muted hover:text-foreground hover:bg-gray-100 rounded-lg transition-colors"
                  >
                    キャンセル
                  </button>
                  <button
                    onClick={handleCreatePost}
                    disabled={!newPostText.trim() || posting}
                    className="px-6 py-2.5 bg-gradient-to-r from-[#1a2a5e] to-[#2b3d8b] text-white rounded-xl text-sm font-bold hover:from-[#223370] hover:to-[#3b4da0] transition-all disabled:opacity-50 shadow-sm"
                  >
                    {posting ? "投稿中..." : "投稿"}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Timeline Tab */}
      {activeTab === "timeline" && (
        <>
          {posts.length === 0 ? (
            <div className="text-center py-24 bg-white rounded-2xl border border-gray-200 shadow-sm">
              <div className="w-16 h-16 mx-auto mb-5 rounded-2xl bg-gradient-to-br from-[#1a2a5e] to-[#3b5bdb] flex items-center justify-center shadow-lg">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                </svg>
              </div>
              <h3 className="text-lg font-bold text-foreground mb-2">
                まだ投稿がありません
              </h3>
              <p className="text-sm text-muted">
                最初の投稿を作成してみましょう
              </p>
            </div>
          ) : (
            <div className="space-y-5">
              {posts.map((post) => (
                <div
                  key={post.id}
                  className="bg-white rounded-2xl border border-gray-200 border-l-4 border-l-[#1a2a5e] p-6 shadow-sm hover:shadow-md transition-shadow duration-200"
                >
                  {/* Post Header */}
                  <div className="flex items-center gap-3 mb-4">
                    <Link href={`/profile/${post.userId}`}>
                      <div className="w-11 h-11 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden ring-2 ring-primary/20">
                        {post.userAvatarUrl ? (
                          <img
                            src={post.userAvatarUrl}
                            alt=""
                            className="w-11 h-11 object-cover"
                          />
                        ) : (
                          post.userNickname?.charAt(0) || "?"
                        )}
                      </div>
                    </Link>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <Link
                          href={`/profile/${post.userId}`}
                          className="text-sm font-bold text-foreground hover:text-primary transition-colors"
                        >
                          {post.userNickname}
                        </Link>
                        {post.badgeName && (
                          <span className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full font-medium">
                            {post.badgeName}
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-muted mt-0.5">
                        {relativeTime(post.createdAt)}
                      </p>
                    </div>
                  </div>

                  {/* Post Body */}
                  <p className="text-sm text-foreground whitespace-pre-wrap mb-4 leading-relaxed">
                    {post.text}
                  </p>

                  {/* Images — Clickable for lightbox */}
                  {post.images && post.images.length > 0 && (
                    <div className={`mb-4 ${post.images.length > 1 ? "grid grid-cols-2 gap-2" : ""}`}>
                      {post.images.map((img, i) => (
                        <img
                          key={i}
                          src={img}
                          alt=""
                          onClick={() => setLightboxSrc(img)}
                          className="rounded-xl max-h-80 w-full object-cover border border-gray-100 image-clickable cursor-zoom-in hover:opacity-90 transition-opacity"
                        />
                      ))}
                    </div>
                  )}

                  {/* Actions — Colored hover backgrounds */}
                  <div className="flex items-center gap-3 pt-3 border-t border-gray-100">
                    <button
                      onClick={() => handleLike(post.id)}
                      disabled={!user}
                      className={`flex items-center gap-1.5 text-sm px-3 py-1.5 rounded-lg transition-all ${
                        likedMap[post.id]
                          ? "text-red-500 bg-red-50"
                          : "text-muted hover:text-red-500 hover:bg-red-500/10"
                      } disabled:opacity-50 disabled:hover:bg-transparent`}
                    >
                      <svg
                        className="w-4.5 h-4.5"
                        fill={likedMap[post.id] ? "currentColor" : "none"}
                        stroke="currentColor"
                        strokeWidth={2}
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z"
                        />
                      </svg>
                      <span className="font-medium">{post.likesCount}</span>
                    </button>
                    <button
                      onClick={() => toggleComments(post.id)}
                      className={`flex items-center gap-1.5 text-sm px-3 py-1.5 rounded-lg transition-all ${
                        expandedComments[post.id]
                          ? "text-primary bg-blue-50"
                          : "text-muted hover:text-primary hover:bg-blue-500/10"
                      }`}
                    >
                      <svg
                        className="w-4.5 h-4.5"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                        />
                      </svg>
                      <span className="font-medium">{post.commentsCount}</span>
                    </button>
                  </div>

                  {/* Comments Section */}
                  {expandedComments[post.id] && (
                    <div className="mt-4 pt-4 border-t border-gray-100">
                      {commentsMap[post.id]?.length === 0 && (
                        <p className="text-xs text-muted text-center py-4">
                          まだコメントはありません
                        </p>
                      )}
                      <div className="space-y-3">
                        {commentsMap[post.id]?.map((comment) => (
                          <div key={comment.id} className="flex gap-2.5">
                            <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-xs flex-shrink-0 overflow-hidden ring-1 ring-primary/10">
                              {comment.userAvatarUrl ? (
                                <img
                                  src={comment.userAvatarUrl}
                                  alt=""
                                  className="w-7 h-7 object-cover"
                                />
                              ) : (
                                comment.userNickname?.charAt(0) || "?"
                              )}
                            </div>
                            <div className="flex-1 bg-gray-50 rounded-xl px-3.5 py-2.5">
                              <div className="flex items-baseline gap-2">
                                <span className="text-xs font-bold text-foreground">
                                  {comment.userNickname}
                                </span>
                                <span className="text-xs text-muted">
                                  {relativeTime(comment.createdAt)}
                                </span>
                              </div>
                              <p className="text-sm text-foreground mt-0.5">
                                {comment.text}
                              </p>
                            </div>
                          </div>
                        ))}
                      </div>

                      {/* Comment Input */}
                      {user && profile && (
                        <div className="flex gap-2 mt-4">
                          <input
                            type="text"
                            value={commentTexts[post.id] || ""}
                            onChange={(e) =>
                              setCommentTexts((prev) => ({
                                ...prev,
                                [post.id]: e.target.value,
                              }))
                            }
                            onKeyDown={(e) => {
                              if (e.key === "Enter" && !e.shiftKey) {
                                e.preventDefault();
                                handleComment(post.id);
                              }
                            }}
                            placeholder="コメントを入力..."
                            className="flex-1 border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/10 transition-all"
                          />
                          <button
                            onClick={() => handleComment(post.id)}
                            disabled={!commentTexts[post.id]?.trim()}
                            className="px-5 py-2.5 bg-gradient-to-r from-[#1a2a5e] to-[#2b3d8b] text-white rounded-xl text-sm font-bold hover:from-[#223370] hover:to-[#3b4da0] transition-all disabled:opacity-50 shadow-sm"
                          >
                            送信
                          </button>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* Notices Tab */}
      {activeTab === "notices" && (
        <>
          {noticesLoading ? (
            <div className="flex items-center justify-center py-16">
              <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
          ) : notices.length === 0 ? (
            <div className="text-center py-24 bg-white rounded-2xl border border-gray-200 shadow-sm">
              <div className="w-16 h-16 mx-auto mb-5 rounded-2xl bg-gradient-to-br from-amber-400 to-yellow-500 flex items-center justify-center shadow-lg">
                <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
                </svg>
              </div>
              <h3 className="text-lg font-bold text-foreground mb-2">
                お知らせはありません
              </h3>
              <p className="text-sm text-muted">
                新しいお知らせがあるとここに表示されます
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {notices.map((notice) => (
                <div
                  key={notice.id}
                  className={`bg-white rounded-2xl border border-gray-200 border-l-4 ${noticeBorderColor(notice.type)} p-6 shadow-sm hover:shadow-md transition-shadow duration-200`}
                >
                  <div className="flex items-center gap-2 mb-2.5">
                    <span className="text-xs bg-primary/10 text-primary px-2.5 py-1 rounded-full font-semibold">
                      {notice.type}
                    </span>
                    <span className="text-xs text-muted">
                      {relativeTime(notice.createdAt)}
                    </span>
                  </div>
                  <h3 className="text-sm font-bold text-foreground mb-1.5">
                    {notice.title}
                  </h3>
                  <p className="text-sm text-muted whitespace-pre-wrap leading-relaxed">
                    {notice.body}
                  </p>
                </div>
              ))}
            </div>
          )}
        </>
      )}

      {/* Image Lightbox */}
      {lightboxSrc && <ImageLightbox src={lightboxSrc} onClose={() => setLightboxSrc(null)} />}
    </div>
  );
}

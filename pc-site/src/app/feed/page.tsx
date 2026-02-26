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

  const tabs: { key: Tab; label: string }[] = [
    { key: "timeline", label: "タイムライン" },
    { key: "notices", label: "お知らせ" },
  ];

  if (authLoading || loading) {
    return (
      <div className="flex items-center justify-center py-32">
        <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-[800px] mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-foreground">フィード</h1>
        {user && profile && (
          <button
            onClick={() => setShowPostForm(!showPostForm)}
            className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            投稿する
          </button>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 bg-gray-100 rounded-lg p-1 mb-6">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${
              activeTab === tab.key
                ? "bg-white text-foreground shadow-sm"
                : "text-muted hover:text-foreground"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Create Post Form */}
      {showPostForm && user && profile && (
        <div className="bg-white rounded-xl border border-gray-200 p-5 mb-6">
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden">
              {profile.avatarUrl ? (
                <img src={profile.avatarUrl} alt="" className="w-10 h-10 object-cover" />
              ) : (
                profile.nickname?.charAt(0) || "U"
              )}
            </div>
            <div className="flex-1">
              <textarea
                value={newPostText}
                onChange={(e) => setNewPostText(e.target.value)}
                placeholder="いまどうしてる?"
                className="w-full border border-gray-200 rounded-lg p-3 text-sm text-foreground resize-none focus:outline-none focus:border-primary"
                rows={3}
              />
              <input
                type="text"
                value={newPostImage}
                onChange={(e) => setNewPostImage(e.target.value)}
                placeholder="画像URL (任意)"
                className="w-full border border-gray-200 rounded-lg p-2.5 text-sm text-foreground mt-2 focus:outline-none focus:border-primary"
              />
              <div className="flex justify-end mt-3">
                <button
                  onClick={() => setShowPostForm(false)}
                  className="px-4 py-2 text-sm text-muted hover:text-foreground mr-2"
                >
                  キャンセル
                </button>
                <button
                  onClick={handleCreatePost}
                  disabled={!newPostText.trim() || posting}
                  className="px-5 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
                >
                  {posting ? "投稿中..." : "投稿"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Timeline Tab */}
      {activeTab === "timeline" && (
        <>
          {posts.length === 0 ? (
            <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
              <div className="text-4xl mb-4">📝</div>
              <h3 className="text-lg font-bold text-foreground mb-2">
                まだ投稿がありません
              </h3>
              <p className="text-sm text-muted">
                最初の投稿を作成してみましょう
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {posts.map((post) => (
                <div
                  key={post.id}
                  className="bg-white rounded-xl border border-gray-200 p-5"
                >
                  {/* Post Header */}
                  <div className="flex items-center gap-3 mb-3">
                    <Link href={`/profile/${post.userId}`}>
                      <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-sm flex-shrink-0 overflow-hidden">
                        {post.userAvatarUrl ? (
                          <img
                            src={post.userAvatarUrl}
                            alt=""
                            className="w-10 h-10 object-cover"
                          />
                        ) : (
                          post.userNickname?.charAt(0) || "?"
                        )}
                      </div>
                    </Link>
                    <div className="flex-1 min-w-0">
                      <Link
                        href={`/profile/${post.userId}`}
                        className="text-sm font-bold text-foreground hover:text-primary transition-colors"
                      >
                        {post.userNickname}
                      </Link>
                      {post.badgeName && (
                        <span className="ml-2 text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full">
                          {post.badgeName}
                        </span>
                      )}
                      <p className="text-xs text-muted">
                        {relativeTime(post.createdAt)}
                      </p>
                    </div>
                  </div>

                  {/* Post Body */}
                  <p className="text-sm text-foreground whitespace-pre-wrap mb-3">
                    {post.text}
                  </p>

                  {/* Images */}
                  {post.images && post.images.length > 0 && (
                    <div className={`mb-3 ${post.images.length > 1 ? "grid grid-cols-2 gap-2" : ""}`}>
                      {post.images.map((img, i) => (
                        <img
                          key={i}
                          src={img}
                          alt=""
                          className="rounded-xl max-h-80 w-full object-cover border border-gray-100"
                        />
                      ))}
                    </div>
                  )}

                  {/* Actions */}
                  <div className="flex items-center gap-6 pt-2 border-t border-gray-100">
                    <button
                      onClick={() => handleLike(post.id)}
                      disabled={!user}
                      className={`flex items-center gap-1.5 text-sm transition-colors ${
                        likedMap[post.id]
                          ? "text-red-500"
                          : "text-muted hover:text-red-500"
                      } disabled:opacity-50`}
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
                      <span>{post.likesCount}</span>
                    </button>
                    <button
                      onClick={() => toggleComments(post.id)}
                      className="flex items-center gap-1.5 text-sm text-muted hover:text-primary transition-colors"
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
                      <span>{post.commentsCount}</span>
                    </button>
                  </div>

                  {/* Comments Section */}
                  {expandedComments[post.id] && (
                    <div className="mt-4 pt-3 border-t border-gray-100">
                      {commentsMap[post.id]?.length === 0 && (
                        <p className="text-xs text-muted text-center py-3">
                          まだコメントはありません
                        </p>
                      )}
                      <div className="space-y-3">
                        {commentsMap[post.id]?.map((comment) => (
                          <div key={comment.id} className="flex gap-2.5">
                            <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-xs flex-shrink-0 overflow-hidden">
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
                            <div className="flex-1 bg-gray-50 rounded-lg px-3 py-2">
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
                        <div className="flex gap-2 mt-3">
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
                            className="flex-1 border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:border-primary"
                          />
                          <button
                            onClick={() => handleComment(post.id)}
                            disabled={!commentTexts[post.id]?.trim()}
                            className="px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors disabled:opacity-50"
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
            <div className="text-center py-20 bg-white rounded-xl border border-gray-200">
              <div className="text-4xl mb-4">📢</div>
              <h3 className="text-lg font-bold text-foreground mb-2">
                お知らせはありません
              </h3>
              <p className="text-sm text-muted">
                新しいお知らせがあるとここに表示されます
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {notices.map((notice) => (
                <div
                  key={notice.id}
                  className="bg-white rounded-xl border border-gray-200 p-5"
                >
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-xs bg-primary/10 text-primary px-2 py-0.5 rounded-full font-medium">
                      {notice.type}
                    </span>
                    <span className="text-xs text-muted">
                      {relativeTime(notice.createdAt)}
                    </span>
                  </div>
                  <h3 className="text-sm font-bold text-foreground mb-1">
                    {notice.title}
                  </h3>
                  <p className="text-sm text-muted whitespace-pre-wrap">
                    {notice.body}
                  </p>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

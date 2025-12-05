# TaskChain - System Architecture & Feature Flows Documentation

## Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Technology Stack](#technology-stack)
3. [High-Level Architecture](#high-level-architecture)
4. [Firebase Infrastructure](#firebase-infrastructure)
5. [Service Layer Architecture](#service-layer-architecture)
6. [Data Models](#data-models)
7. [Feature Flows](#feature-flows)
8. [Real-Time Communication](#real-time-communication)
9. [Security Architecture](#security-architecture)

---

## System Architecture Overview

TaskChain is a cross-platform Flutter application built on Firebase backend services, implementing a real-time habit tracking system with social features, premium subscriptions, and AI-powered coaching.

### Architecture Pattern
- **Frontend**: Flutter (Dart) - MVVM pattern with service layer
- **Backend**: Firebase (Firestore, Auth, Cloud Messaging, Cloud Functions, Storage)
- **Real-time**: Firestore Streams + FCM Push Notifications
- **State Management**: BLoC (Settings), ValueNotifier (Navigation), setState (UI)

```
┌─────────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                               │
│                    (Flutter/Dart Application)                       │
├─────────────────────────────────────────────────────────────────────┤
│  Presentation Layer          │  Business Logic Layer                │
│  • Pages/UI Components       │  • Services (Chain, User, Shop)      │
│  • Widgets                   │  • Models                             │
│  • State Management          │  • Repository Pattern                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/WebSocket
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       FIREBASE BACKEND                              │
├─────────────────────────────────────────────────────────────────────┤
│  • Firestore (Database)      │  • Cloud Functions (Serverless)     │
│  • Firebase Auth             │  • Cloud Messaging (FCM)            │
│  • Firebase Storage          │  • Firestore Security Rules         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ API Calls
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SERVICES                                │
│  • Airia AI API (AI Coaching)                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

### Frontend
- **Framework**: Flutter 3.9.2+
- **Language**: Dart 3.9.2+
- **UI**: Material Design 3
- **State Management**: 
  - flutter_bloc (Settings)
  - ValueNotifier (Navigation, Inbox)
  - setState (Component-level)

### Backend Services
- **Firebase Core**: Authentication, Database, Storage
- **Cloud Firestore**: NoSQL real-time database
- **Firebase Authentication**: Email/Password auth
- **Firebase Cloud Messaging (FCM)**: Push notifications
- **Cloud Functions**: Serverless backend logic
- **Firebase Storage**: Media file storage

### External Integrations
- **Airia AI API**: Personalized AI coaching messages
- **QR Code Generation**: qr_flutter package
- **Image Picker**: Camera and gallery access
- **Audio Recording**: Record package

### Key Dependencies
```yaml
firebase_core: ^3.0.0
firebase_auth: ^5.0.0
cloud_firestore: ^5.0.0
firebase_messaging: ^15.0.0
firebase_storage: ^12.0.0
flutter_bloc: ^8.1.6
http: ^1.2.0
confetti: ^0.7.0
```

---

## High-Level Architecture

### Application Flow
```
┌─────────────────────────────────────────────────────────────┐
│                    APP INITIALIZATION                       │
│                   (lib/main.dart)                           │
└────────────────────────┬────────────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            │                         │
    ┌───────▼──────┐        ┌────────▼────────┐
    │  Firebase    │        │  Notification   │
    │ Initialize   │        │  Service Init   │
    └───────┬──────┘        └────────┬────────┘
            │                        │
            └────────────┬───────────┘
                         │
            ┌────────────▼────────────┐
            │   ChainzApp Widget      │
            │ (Auth State Stream)     │
            └────────────┬────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
    ┌────▼─────┐                  ┌──────▼──────┐
    │ Not Auth │                  │   Auth      │
    │          │                  │             │
    │ • Onboard│                  │ • RootShell │
    │ • SignIn │                  │   (3 Tabs)  │
    │ • SignUp │                  └──────┬──────┘
    └──────────┘                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
            ┌───────▼──────┐    ┌────────▼────────┐  ┌───────▼──────┐
            │  Home Page   │    │ Create Chain    │  │ Profile Page │
            │              │    │   Step 1        │  │              │
            └───────┬──────┘    └────────┬────────┘  └───────┬──────┘
                    │                    │                    │
```

### Main Navigation Structure (RootShell)
```
RootShell (Bottom Navigation Bar)
├── Home Tab (HomePage)
│   ├── View Active Chains (Stream from Firestore)
│   ├── Join Chain (QR Scanner / Manual Code)
│   ├── Stats Display
│   │   ├── Total Days Completed
│   │   ├── Current Streak
│   │   ├── Success Rate
│   │   └── Longest Streak
│   ├── Quick Access Cards
│   │   ├── Shop
│   │   └── AI Coach
│   └── Chain Cards (Navigate to Chain Detail)
│
├── Create Tab (CreateChainStep1)
│   ├── Step 1: Chain Details
│   │   ├── Title & Description
│   │   ├── Start Date Selection
│   │   └── Duration (days)
│   └── Step 2: Theme Selection
│       ├── Available Themes (Free + Purchased)
│       ├── Chain Limit Check
│       └── Create Chain
│
└── Profile Tab (ProfilePage)
    ├── User Stats & Info
    ├── Friends List
    ├── Inbox (Friend Requests + Chain Invites)
    ├── Settings
    ├── Edit Profile
    └── Achievements
```

---

## Firebase Infrastructure

### Firestore Database Structure

```
Firestore Database
│
├── users/{userId}
│   ├── Profile Fields
│   │   ├── email: String
│   │   ├── displayName: String
│   │   ├── bio: String
│   │   ├── location: String
│   │   ├── fcmToken: String
│   │   │
│   │   ├── Currency & Premium
│   │   │   ├── coins: int
│   │   │   ├── isPremium: bool
│   │   │   ├── premiumType: String? ("lifetime" | "monthly" | "yearly")
│   │   │   ├── premiumExpiresAt: Timestamp?
│   │   │   └── purchasedThemes: List<String>
│   │   │
│   │   └── Statistics
│   │       ├── checkIns: int
│   │       ├── currentStreak: int
│   │       ├── longestStreak: int
│   │       ├── successRate: double
│   │       ├── firstChainJoinDate: String? ("yyyy-MM-dd")
│   │       └── lastActiveDate: String? ("yyyy-MM-dd")
│   │
│   ├── Subcollections
│   │   ├── friends/{friendId}
│   │   │   └── userId, email, displayName, createdAt
│   │   │
│   │   ├── friendRequests/{requestId}
│   │   │   └── fromUserId, fromEmail, fromDisplayName, status, createdAt
│   │   │
│   │   ├── chainInvites/{inviteId}
│   │   │   └── chainId, chainTitle, chainCode, inviterId, status, createdAt
│   │   │
│   │   ├── groupReminders/{reminderId}
│   │   │   └── chainId, chainTitle, message, type, read, sent, createdAt
│   │   │
│   │   └── coinTransactions/{transactionId}
│   │       └── amount, type, reason, timestamp
│   │
│   └── AI Chatbot Tracking
│       ├── aiMessagesToday: int
│       └── aiMessagesDate: String? ("yyyy-MM-dd")
│
├── chains/{chainId}
│   ├── Chain Metadata
│   │   ├── title: String
│   │   ├── ownerId: String
│   │   ├── code: String (unique, 6-char)
│   │   ├── theme: String
│   │   ├── frequency: String
│   │   ├── startDate: Timestamp
│   │   ├── durationDays: int
│   │   ├── createdAt: Timestamp
│   │   │
│   │   └── Progress Tracking
│   │       ├── memberCount: int
│   │       ├── currentStreak: int (group streak)
│   │       ├── totalDaysCompleted: int
│   │       ├── lastGroupCheckInDate: String? ("yyyy-MM-dd")
│   │       └── lastCompletionStatus: bool
│   │
│   └── Subcollections
│       ├── members/{memberId}
│       │   └── userId, email, role, joinedAt, lastCheckInDate, streak
│       │
│       └── messages/{messageId}
│           └── chainId, senderId, senderName, text, imageUrl, audioUrl, timestamp
│
└── Indexes (Composite)
    ├── Collection Group: members
    │   └── userId + joinedAt (for querying user's chains)
    │
    └── Collection: chains
        └── code (for quick chain lookup by code)
```

### Firebase Cloud Functions

```
Cloud Functions (Node.js)
│
├── sendGroupReminder
│   └── Trigger: users/{userId}/groupReminders/{reminderId}.onCreate
│   └── Action: Send FCM notification to user
│   └── Marks reminder as sent
│
└── sendMessageNotification
    └── Trigger: chains/{chainId}/messages/{messageId}.onCreate
    └── Action: Send FCM to chain topic (chain_{chainId})
    └── Filters out system messages
```

---

## Service Layer Architecture

### Service Classes Overview

```
Services Layer
│
├── Core Services
│   ├── AuthService
│   │   └── Firebase Authentication wrapper
│   │
│   ├── ChainService
│   │   ├── createChain()
│   │   ├── joinChainByCode()
│   │   ├── completeDailyActivity()
│   │   ├── updateChainTheme()
│   │   ├── leaveChain()
│   │   ├── streamJoinedChains()
│   │   └── checkChainLimit()
│   │
│   └── UserService
│       ├── ensureUserProfile()
│       ├── getUserProfile()
│       └── updateUserProfile()
│
├── Feature Services
│   ├── CurrencyService
│   │   ├── getCoins()
│   │   ├── addCoins()
│   │   ├── deductCoins()
│   │   ├── earnCoinsFromCheckIn()
│   │   ├── earnCoinsFromStreak()
│   │   └── earnCoinsFromChainCompletion()
│   │
│   ├── ShopService
│   │   ├── getAvailableThemes()
│   │   ├── purchaseTheme()
│   │   ├── purchasePremium()
│   │   └── isPremiumActive()
│   │
│   ├── FriendService
│   │   ├── sendFriendRequest()
│   │   ├── acceptFriendRequest()
│   │   ├── sendChainInvite()
│   │   ├── streamFriends()
│   │   └── streamFriendRequests()
│   │
│   └── MessageService
│       ├── sendMessage()
│       ├── getChainMessages()
│       └── deleteMessage()
│
└── Integration Services
    ├── NotificationService
    │   ├── initialize()
    │   ├── subscribeToTopic()
    │   ├── unsubscribeFromTopic()
    │   └── showInboxNotification()
    │
    ├── AiriaService
    │   ├── sendMessage()
    │   └── _getUserChainContext()
    │
    └── GroupReminderService
        ├── remindGroupMembers()
        └── _generatePersonalizedReminder()
```

---

## Data Models

### Core Models

#### Chain Model
```dart
Chain {
  String id
  String title
  String code (unique, 6 characters)
  String ownerId
  String theme
  int durationDays
  int memberCount
  int currentStreak (group streak)
  int totalDaysCompleted
  double progress (0.0 - 1.0, computed)
  
  // UI formatted strings
  String days ("30 days")
  String members ("2 members")
}
```

#### User Profile Model
```dart
UserProfile {
  String userId
  String email
  String displayName
  String bio
  String location
  
  // Currency & Premium
  int coins
  bool isPremium
  String? premiumType
  Timestamp? premiumExpiresAt
  List<String> purchasedThemes
  
  // Statistics
  int checkIns
  int currentStreak
  int longestStreak
  double successRate
  String? firstChainJoinDate
  String? lastActiveDate
  
  // AI Chatbot
  int aiMessagesToday
  String? aiMessagesDate
}
```

#### Chain Member Model
```dart
ChainMember {
  String userId
  String email
  String role ("owner" | "member")
  Timestamp joinedAt
  String? lastCheckInDate
  int streak
}
```

#### Message Model
```dart
Message {
  String id
  String chainId
  String senderId
  String senderName
  String? text
  String? imageUrl
  String? audioUrl
  DateTime timestamp
}
```

---

## Feature Flows

### 1. Authentication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     APP STARTUP                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │  Load Environment (.env)│
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  Firebase.initializeApp()│
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  NotificationService    │
              │  .initialize()          │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  ChainzApp Widget       │
              │  (AuthStateChanges)     │
              └────────────┬────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
   ┌────▼────┐                          ┌────▼─────┐
   │ No User │                          │ Has User │
   │         │                          │          │
   └────┬────┘                          └────┬─────┘
        │                                     │
   ┌────▼────────────────┐                  │
   │ Check Onboarding    │                  │
   │ Flag                │                  │
   └────┬────────────────┘                  │
        │                                   │
   ┌────▼────────────┐              ┌──────▼────────┐
   │ OnboardingPage  │              │  RootShell    │
   │ (First Time)    │              │  (Main App)   │
   └────┬────────────┘              └───────────────┘
        │
   ┌────▼────────────┐
   │ SignInPage      │
   │                 │
   │ • Email Input   │
   │ • Password      │
   │ • Sign Up Link  │
   └────┬────────────┘
        │
   ┌────▼────────────┐
   │ Firebase Auth   │
   │ Sign In         │
   └────┬────────────┘
        │
        └───────────→ RootShell
```

### 2. Chain Creation Flow

```
User Taps "Create Chain"
        │
        ▼
┌───────────────────────────────┐
│  CreateChainStep1             │
│                               │
│  • Enter Chain Title          │
│  • Select Start Date          │
│  • Set Duration (days)        │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  CreateChainStep2             │
│                               │
│  • Load Available Themes      │
│    - Free Themes              │
│    - Purchased Themes         │
│  • Select Theme               │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  ChainService.checkChainLimit()│
│                               │
│  • Check if Premium User      │
│  • Count Active Chains        │
│  • Free: Max 2 chains         │
│  • Premium: Unlimited         │
└───────────┬───────────────────┘
            │
      ┌─────┴─────┐
      │           │
   Limit    ┌─────▼─────┐
   Reached  │ Create    │
      │     │ Chain     │
      ▼     └─────┬─────┘
┌──────────┐      │
│ Show     │      │
│ Upgrade  │      │
│ Dialog   │      │
└──────────┘      │
                  │
                  ▼
        ┌─────────────────────┐
        │ ChainService        │
        │ .createChain()      │
        │                     │
        │ 1. Generate Unique  │
        │    Code (6 chars)   │
        │                     │
        │ 2. Create Chain Doc │
        │    in Firestore     │
        │                     │
        │ 3. Add Owner as     │
        │    Member           │
        │                     │
        │ 4. Set firstChain   │
        │    JoinDate if new  │
        │                     │
        │ 5. Subscribe to FCM │
        │    Topic            │
        └──────────┬──────────┘
                   │
                   ▼
        ┌─────────────────────┐
        │ Navigate to Chain   │
        │ Detail Page         │
        └─────────────────────┘
```

### 3. Daily Check-In Flow (Complete Activity)

```
User Opens Chain Detail Page
        │
        ▼
┌───────────────────────────────┐
│  Display Chain Information    │
│                               │
│  • Progress Ring              │
│  • Member List                │
│  • Chat Messages              │
│  • Complete Button            │
└───────────┬───────────────────┘
            │
            ▼
User Clicks "Complete Today"
        │
        ▼
┌───────────────────────────────┐
│  ChainService                 │
│  .completeDailyActivity()     │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Firestore Transaction        │
│                               │
│  1. Check if Already          │
│     Checked In Today          │
│     → Throw Error if Yes      │
│                               │
│  2. Update Member's           │
│     lastCheckInDate = today   │
│                               │
│  3. Count Members Who         │
│     Checked In Today          │
│                               │
│  4. If All Members            │
│     Checked In:               │
│     • Increment               │
│       totalDaysCompleted      │
│     • Increment               │
│       currentStreak           │
│     • Set                     │
│       lastCompletionStatus    │
│       = true                  │
│                               │
│  5. If Not All Checked In:    │
│     • Set                     │
│       lastCompletionStatus    │
│       = false                 │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Update User Global Stats     │
│                               │
│  _updateUserStatsAfterCheckIn()│
│                               │
│  1. Backfill                  │
│     firstChainJoinDate        │
│     if missing                │
│                               │
│  2. Calculate Streak:         │
│     • If lastActive ==        │
│       yesterday: increment    │
│     • Else: reset to 1        │
│                               │
│  3. Update longestStreak      │
│     if current > longest      │
│                               │
│  4. Increment checkIns        │
│                               │
│  5. Calculate Success Rate:   │
│     (checkIns / totalDays)    │
│     * 100                     │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Award Coins                  │
│                               │
│  1. CurrencyService           │
│     .earnCoinsFromCheckIn()   │
│     → +5 coins                │
│                               │
│  2. Check Streak Milestone    │
│     (every 7 days)            │
│     → +10 bonus coins         │
│                               │
│  3. Check Chain Completion    │
│     (if 100%)                 │
│     → +50 coins               │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Check for 100% Completion    │
│                               │
│  If progress >= 1.0:          │
│  • Trigger Confetti           │
│    Animation                  │
│  • Show Celebration           │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Optional: Send Reminders     │
│                               │
│  GroupReminderService         │
│  .remindGroupMembers()        │
│                               │
│  1. Find Members Who          │
│     Haven't Checked In        │
│                               │
│  2. Get User Profiles         │
│     for Personalization       │
│                               │
│  3. Generate AI Messages      │
│     (Airia API)               │
│                               │
│  4. Store Reminders in        │
│     Firestore                 │
│                               │
│  5. Cloud Function            │
│     Sends FCM Notifications   │
└───────────────────────────────┘
```

### 4. Shop & Premium Features Flow

```
User Opens Shop Page
        │
        ▼
┌───────────────────────────────┐
│  Load User Data               │
│                               │
│  • Current Coin Balance       │
│  • Premium Status             │
│  • Purchased Themes           │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Display Tabs                 │
│                               │
│  • Themes Tab                 │
│  • Premium Tab                │
│  • Coins Tab                  │
└───────────┬───────────────────┘
            │
    ┌───────┴───────┐
    │               │
    ▼               ▼
┌─────────┐   ┌─────────────┐
│ Themes  │   │ Premium     │
└────┬────┘   └─────┬───────┘
     │              │
     ▼              ▼
┌───────────────────────────────┐
│  Purchase Flow                │
│                               │
│  1. User Selects Item         │
│                               │
│  2. Check Coins Balance       │
│     → Show Error if           │
│       Insufficient            │
│                               │
│  3. Show Confirmation         │
│     Dialog                    │
│                               │
│  4. ShopService.purchase()    │
│     • Deduct Coins            │
│     • Update User Profile     │
│       (theme/premium)         │
│                               │
│  5. Refresh UI                │
│     • Update Balance          │
│     • Show Success Message    │
└───────────────────────────────┘
```

### 5. Friend & Social Features Flow

```
Profile Page → Friends Section
        │
        ▼
┌───────────────────────────────┐
│  View Friends List            │
│  (FriendService.streamFriends())│
└───────────┬───────────────────┘
            │
    ┌───────┴───────┐
    │               │
    ▼               ▼
┌──────────┐   ┌──────────────┐
│ Send     │   │ Inbox        │
│ Request  │   │              │
└────┬─────┘   └──────┬───────┘
     │                │
     ▼                ▼
┌───────────────────────────────┐
│  Send Friend Request          │
│                               │
│  1. Enter Friend Email        │
│                               │
│  2. FriendService             │
│     .sendFriendRequest()      │
│     • Find User by Email      │
│     • Create Request Doc      │
│       in Friend's Inbox       │
│                               │
│  3. Notification Sent         │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Accept Friend Request        │
│                               │
│  FriendService                │
│  .acceptFriendRequest()       │
│                               │
│  1. Create Mutual Friend      │
│     Documents                 │
│     • Current User's          │
│       Friends List            │
│     • Friend's Friends List   │
│                               │
│  2. Mark Request as Accepted  │
└───────────────────────────────┘
```

### 6. AI Coach (Chatbot) Flow

```
Home Page → Quick Access Card
        │
        ▼
┌───────────────────────────────┐
│  ChatbotPage                  │
│                               │
│  1. Load Premium Status       │
│  2. Load Message Count        │
│     (Free: 5/day limit)       │
└───────────┬───────────────────┘
            │
            ▼
User Sends Message
        │
        ▼
┌───────────────────────────────┐
│  Check Message Limit          │
│                               │
│  • Free User: Check if        │
│    < 5 messages today         │
│    → Show Upgrade Dialog      │
│      if exceeded              │
│                               │
│  • Premium User: Unlimited    │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  AiriaService.sendMessage()   │
│                               │
│  1. Get User Context          │
│     _getUserChainContext()    │
│     • User Profile            │
│     • All Joined Chains       │
│     • Chain Progress          │
│     • Stats & Streaks         │
│                               │
│  2. Build Context Object      │
│     for AI                    │
│                               │
│  3. Call Airia API            │
│     • Pipeline ID             │
│     • User Message            │
│     • Context Data            │
│                               │
│  4. Return AI Response        │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Display Response             │
│                               │
│  • Add to Conversation        │
│  • Increment Message Count    │
│    (Free Users)               │
│  • Reset Count at Midnight    │
└───────────────────────────────┘
```

### 7. Real-Time Notifications Flow

```
Chain Member Completes Check-In
        │
        ▼
┌───────────────────────────────┐
│  GroupReminderService         │
│  .remindGroupMembers()        │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Find Members to Remind       │
│                               │
│  • Query Chain Members        │
│  • Filter: lastCheckInDate    │
│    != today                   │
│  • Exclude Checked-In User    │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Generate Personalized        │
│  Reminders                    │
│                               │
│  For Each Member:             │
│  1. Get User Profile          │
│  2. Call Airia API            │
│     (Reminder Pipeline)       │
│  3. Generate Personalized     │
│     Message                   │
│  4. Store in Firestore        │
│     users/{userId}/           │
│     groupReminders/{id}       │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  Cloud Function Triggered     │
│                               │
│  sendGroupReminder            │
│  (onCreate listener)          │
│                               │
│  1. Get User's FCM Token      │
│  2. Send FCM Notification     │
│  3. Mark Reminder as Sent     │
└───────────┬───────────────────┘
            │
            ▼
┌───────────────────────────────┐
│  User Receives Notification   │
│                               │
│  • Push Notification          │
│  • Personalized Message       │
│  • Tap to Open Chain          │
└───────────────────────────────┘
```

---

## Real-Time Communication

### Firestore Streams

```
Real-Time Data Flow:

User Action → Service Method → Firestore Update
                                        │
                                        ├─→ Firestore Stream Listener Triggered
                                        │
                                        └─→ UI Updates Automatically
                                              │
                                              └─→ StreamBuilder / setState()
```

### Key Real-Time Streams

1. **Chain List**: `ChainService.streamJoinedChains(userId)`
   - Listens to all chains where user is a member
   - Updates when chain progress changes

2. **Messages**: `MessageService.getChainMessages(chainId)`
   - Real-time chat updates
   - New messages appear instantly

3. **Friend Requests**: `FriendService.streamFriendRequests(userId)`
   - Inbox updates in real-time

4. **Chain Invites**: `FriendService.streamChainInvites(userId)`
   - New invites appear immediately

### FCM Topic Subscriptions

```
Chain Membership Flow:

User Joins Chain
        │
        ▼
Subscribe to FCM Topic: "chain_{chainId}"
        │
        ▼
Receive Notifications:
• New Messages
• Group Reminders
• Chain Updates

User Leaves Chain
        │
        ▼
Unsubscribe from Topic
```

---

## Security Architecture

### Firestore Security Rules Structure

```
Security Rules Hierarchy:

1. Authentication Required
   → All operations require request.auth != null

2. User Profile Access
   → Users can read all profiles
   → Users can only update own profile

3. Chain Access
   → Members can read chain data
   → Only owner can delete chain
   → Only owner can update theme
   → Members can update progress

4. Member Documents
   → Users can read own member doc
   → Users can leave (delete own member doc)
   → Owner can remove members

5. Messages
   → Members can read/create messages
   → Only owner can delete (for chain deletion)

6. Friend System
   → Users can send friend requests
   → Users can only accept/decline own requests
   → Mutual friend documents created securely

7. Group Reminders
   → Any authenticated user can create reminders
   → Users can only read own reminders
   → Cloud Functions can update (via admin SDK)
```

### Key Security Features

1. **Chain Code Generation**: Random 6-character codes, uniqueness verified
2. **Member Verification**: Security rules check membership before allowing operations
3. **Owner Privileges**: Only chain owner can delete chain, change theme
4. **Coin Validation**: Coins deducted before purchase, validated in service layer
5. **Premium Checks**: Server-side validation of premium status
6. **FCM Token Security**: Tokens stored in user's own document, only accessible by user

---

## Key Design Decisions

### 1. Real-Time Updates
- **Choice**: Firestore Streams over polling
- **Reason**: Instant updates, lower battery usage, better UX

### 2. Transaction-Based Check-Ins
- **Choice**: Firestore Transactions for check-in logic
- **Reason**: Prevents race conditions, ensures data consistency

### 3. Service Layer Pattern
- **Choice**: Separate service classes for each domain
- **Reason**: Clean separation of concerns, testability, reusability

### 4. Cloud Functions for Notifications
- **Choice**: Serverless functions for FCM sending
- **Reason**: FCM requires server-side, scalable, cost-effective

### 5. AI Context Building
- **Choice**: Pre-fetch user context before API call
- **Reason**: More personalized, better AI responses

### 6. Chain Limit Enforcement
- **Choice**: Check limits before chain creation
- **Reason**: Better UX, prevents failed operations

### 7. Success Rate Calculation
- **Choice**: Calculate on each check-in
- **Reason**: Always up-to-date, stored for quick access

---

## Performance Optimizations

1. **Composite Indexes**: Firestore indexes for efficient queries
2. **Stream Caching**: Firestore caches stream data locally
3. **Lazy Loading**: Images loaded on-demand
4. **Pagination**: Messages loaded in batches (future enhancement)
5. **Transaction Logging**: Coin transactions non-blocking (try-catch)

---

## Future Enhancements

1. Message pagination for long chat histories
2. Image compression before upload
3. Offline support with Firestore offline persistence
4. Push notification scheduling
5. Analytics integration
6. A/B testing for AI messages
7. Multi-language support expansion

---

## Conclusion

TaskChain implements a robust, scalable architecture using Firebase backend services with Flutter frontend. The service layer pattern ensures clean code organization, while real-time streams provide instant updates. Security rules protect user data, and Cloud Functions handle server-side operations like notifications.

The architecture supports:
- Real-time collaboration
- Scalable user growth
- Premium monetization
- AI-powered features
- Cross-platform deployment


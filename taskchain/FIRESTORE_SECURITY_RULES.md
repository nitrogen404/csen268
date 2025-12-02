# Firestore Security Rules

## Updated Rules for Group Reminders

Add these rules to your Firebase Console → Firestore Database → Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      // Allow users to read their own profile
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow users to update their own profile
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Allow users to create their own profile
      allow create: if request.auth != null && request.auth.uid == userId;
      
      // FCM Token storage
      allow update: if request.auth != null && request.auth.uid == userId;
      
      // Group Reminders subcollection
      // Allow any authenticated user to create reminders for other users
      // (This is needed when someone completes a check-in and wants to remind others)
      match /groupReminders/{reminderId} {
        allow create: if request.auth != null
                      && request.resource.data.keys().hasAll(['chainId', 'chainTitle', 'message', 'type', 'createdAt', 'read', 'sent'])
                      && request.resource.data.type == 'group_checkin_reminder'
                      && request.resource.data.read == false
                      && request.resource.data.sent == false;
        
        // Allow users to read their own reminders
        allow read: if request.auth != null && request.auth.uid == userId;
        
        // Allow users to update their own reminders (mark as read)
        allow update: if request.auth != null && request.auth.uid == userId;
        
        // Cloud Functions can update (mark as sent)
        // This requires admin privileges, so Cloud Functions will handle it
      }
      
      // Friend Requests subcollection
      match /friendRequests/{requestId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow create: if request.auth != null;
        allow update: if request.auth != null && request.auth.uid == userId;
      }
      
      // Friends subcollection
      match /friends/{friendId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow create: if request.auth != null;
        allow delete: if request.auth != null && request.auth.uid == userId;
      }
      
      // Chain Invites subcollection
      match /chainInvites/{inviteId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow create: if request.auth != null;
        allow update: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Chains collection
    match /chains/{chainId} {
      // Allow authenticated users to read chains they're members of
      allow read: if request.auth != null;
      
      // Allow chain owner to create/update/delete
      allow create: if request.auth != null 
                    && request.resource.data.ownerId == request.auth.uid;
      
      allow update: if request.auth != null 
                    && (resource.data.ownerId == request.auth.uid
                        || exists(/databases/$(database)/documents/chains/$(chainId)/members/$(request.auth.uid)));
      
      allow delete: if request.auth != null 
                    && resource.data.ownerId == request.auth.uid;
      
      // Members subcollection
      match /members/{memberId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null;
        allow update: if request.auth != null;
        allow delete: if request.auth != null 
                      && (get(/databases/$(database)/documents/chains/$(chainId)).data.ownerId == request.auth.uid
                          || memberId == request.auth.uid);
      }
      
      // Messages subcollection
      match /messages/{messageId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null 
                      && request.resource.data.senderId == request.auth.uid;
        allow delete: if request.auth != null 
                      && (resource.data.senderId == request.auth.uid
                          || get(/databases/$(database)/documents/chains/$(chainId)).data.ownerId == request.auth.uid);
      }
    }
  }
}
```

## Key Changes for Group Reminders

The important addition is the `groupReminders` subcollection rule:

```javascript
match /groupReminders/{reminderId} {
  // Allow any authenticated user to create reminders for other users
  // This is needed when User A completes check-in and wants to remind User B
  allow create: if request.auth != null
                && request.resource.data.keys().hasAll(['chainId', 'chainTitle', 'message', 'type', 'createdAt', 'read', 'sent'])
                && request.resource.data.type == 'group_checkin_reminder'
                && request.resource.data.read == false
                && request.resource.data.sent == false;
  
  // Users can only read/update their own reminders
  allow read: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null && request.auth.uid == userId;
}
```

## How to Update Rules

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** → **Rules** tab
4. Paste the updated rules above
5. Click **Publish**

## Security Notes

- ✅ Only authenticated users can create reminders
- ✅ Reminders must have the correct structure (validated fields)
- ✅ Users can only read/update their own reminders
- ✅ Cloud Functions can update reminders (using admin SDK) to mark as sent


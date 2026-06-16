const admin = require('firebase-admin');

// Initialize with default credentials
// The emulator might be running or we use default GCP creds
admin.initializeApp({
    projectId: "jaimakali-demo" // wait, let's find the project id from firebaserc
});

async function getExperts() {
    try {
        const snapshot = await admin.firestore().collection('experts').get();
        snapshot.forEach(doc => {
            console.log(doc.id, '=>', doc.data());
        });
    } catch (error) {
        console.error("Error fetching experts:", error);
    }
}

getExperts();

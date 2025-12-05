// src/js/transactions.js
import { loadTransactionsLocal, saveTransactionsLocal } from './storage/local.js';

// Variable locale (privée) pour stocker les transactions en mémoire
let transactions = [];

/**
 * Initialise le module : charge les données depuis le stockage local
 */
export function initTransactions() {
  try {
    const loaded = loadTransactionsLocal();
    transactions = Array.isArray(loaded) ? loaded : [];
  } catch (e) {
    console.error("Erreur lors du chargement des transactions :", e);
    transactions = [];
  }
  
  // ⚠️ TEMPORAIRE : On garde la synchro avec window.transactions
  // car beaucoup de vieux code dans script.js l'utilise encore.
  window.transactions = transactions;
  
  return transactions;
}

/**
 * Récupère toutes les transactions
 */
export function getAllTransactions() {
  return transactions;
}

/**
 * Ajoute une transaction
 */
export function addTransaction(tx) {
  // Générer un ID unique si absent
  if (!tx.id) {
    tx.id = (typeof crypto !== 'undefined' && crypto.randomUUID) 
      ? crypto.randomUUID() 
      : Date.now().toString() + Math.random().toString().slice(2);
  }
  
  transactions.push(tx);
  persist();
  return tx;
}

/**
 * Met à jour une transaction existante
 */
export function updateTransaction(id, updatedFields) {
  const index = transactions.findIndex(t => t.id === String(id));
  if (index !== -1) {
    // On fusionne l'ancienne transaction avec les nouveaux champs
    transactions[index] = { ...transactions[index], ...updatedFields };
    persist();
    return true;
  }
  console.warn(`Transaction introuvable pour mise à jour (ID: ${id})`);
  return false;
}

/**
 * Supprime une transaction
 */
export function deleteTransaction(id) {
  const index = transactions.findIndex(t => t.id === String(id));
  if (index !== -1) {
    transactions.splice(index, 1);
    persist();
    return true;
  }
  console.warn(`Transaction introuvable pour suppression (ID: ${id})`);
  return false;
}

/**
 * Remplace toute la liste (ex: import de fichier ou synchro Cloud)
 */
export function setAllTransactions(newTransactions) {
  if (Array.isArray(newTransactions)) {
    transactions = newTransactions;
    persist();
  }
}

/**
 * Fonction utilitaire interne pour sauvegarder et synchroniser
 */
function persist() {
  saveTransactionsLocal(transactions);
  // Toujours pour la compatibilité temporaire
  window.transactions = transactions;
  
  // On prévient l'application qu'il y a eu du changement
  // (Le calendrier pourra écouter cet événement pour se rafraîchir tout seul)
  window.dispatchEvent(new Event('transactions:changed'));
}

export default { 
  initTransactions, 
  getAllTransactions, 
  addTransaction, 
  updateTransaction, 
  deleteTransaction, 
  setAllTransactions 
};
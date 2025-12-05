// src/js/index.js
import './modules/patches.js';
import './utils/theme.js';
import utils from './utils/format.js';
import * as dom from './utils/dom.js';
import storageLocal from './storage/local.js';
import tx from './transactions.js';

// Expose utilitaires globaux attendus par le reste de l'app (script.js legacy)
window.formatAmount = utils.formatAmount;
window.formatDate = utils.formatDate;
window.parseDate = utils.parseDate;
window.addMonths = utils.addMonths;
window.$$ = dom.$$;
window.onAll = dom.onAll;

// ✅ CORRECTION ICI : On utilise la nouvelle méthode d'initialisation
// (Au lieu de l'ancienne 'bootstrapTransactionsOnce' qui n'existe plus)
if (tx && typeof tx.initTransactions === 'function') {
    tx.initTransactions();
}

console.log('Module entry loaded');

export default {};

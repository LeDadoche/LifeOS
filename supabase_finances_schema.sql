-- =====================================================
-- SCRIPT SQL POUR SUPABASE - Module Finances Premium
-- =====================================================
-- À exécuter dans Supabase SQL Editor

-- 1. MISE À JOUR DE LA TABLE TRANSACTIONS
-- =====================================================
-- Ajouter les nouvelles colonnes à la table existante
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed',
ADD COLUMN IF NOT EXISTS recurring_transaction_id INTEGER,
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Index pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_recurring ON transactions(recurring_transaction_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date_month ON transactions(date);

-- 2. TABLE RECURRING_TRANSACTIONS (Transactions permanentes)
-- =====================================================
CREATE TABLE IF NOT EXISTS recurring_transactions (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    category TEXT NOT NULL DEFAULT 'Autre',
    day_of_month INTEGER NOT NULL CHECK (day_of_month >= 1 AND day_of_month <= 31),
    is_expense BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Index
CREATE INDEX IF NOT EXISTS idx_recurring_user ON recurring_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_recurring_active ON recurring_transactions(is_active);

-- RLS (Row Level Security)
ALTER TABLE recurring_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own recurring transactions" ON recurring_transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own recurring transactions" ON recurring_transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own recurring transactions" ON recurring_transactions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own recurring transactions" ON recurring_transactions
    FOR DELETE USING (auth.uid() = user_id);

-- 3. TABLE FINANCIAL_PROFILE (Profil financier)
-- =====================================================
CREATE TABLE IF NOT EXISTS financial_profile (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE NOT NULL,
    average_salary DECIMAL(12, 2) DEFAULT 0,
    pay_day INTEGER DEFAULT 1 CHECK (pay_day >= 1 AND pay_day <= 31),
    overdraft_limit DECIMAL(12, 2) DEFAULT 0,
    savings_goal DECIMAL(12, 2) DEFAULT 0,
    variable_budget DECIMAL(12, 2) DEFAULT 0,  -- DEPRECATED: use weekly_grocery_budget
    weekly_grocery_budget DECIMAL(12, 2) DEFAULT 0,  -- Budget courses hebdomadaire (famille)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Migration pour base existante
ALTER TABLE financial_profile ADD COLUMN IF NOT EXISTS variable_budget DECIMAL(12, 2) DEFAULT 0;
ALTER TABLE financial_profile ADD COLUMN IF NOT EXISTS weekly_grocery_budget DECIMAL(12, 2) DEFAULT 0;

-- Index
CREATE INDEX IF NOT EXISTS idx_financial_profile_user ON financial_profile(user_id);

-- RLS
ALTER TABLE financial_profile ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own financial profile" ON financial_profile
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own financial profile" ON financial_profile
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own financial profile" ON financial_profile
    FOR UPDATE USING (auth.uid() = user_id);

-- Trigger pour updated_at
CREATE OR REPLACE FUNCTION update_financial_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_financial_profile ON financial_profile;
CREATE TRIGGER trigger_update_financial_profile
    BEFORE UPDATE ON financial_profile
    FOR EACH ROW
    EXECUTE FUNCTION update_financial_profile_updated_at();

-- 4. TABLE SAVINGS_GOALS (Objectifs d'épargne)
-- =====================================================
CREATE TABLE IF NOT EXISTS savings_goals (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    target_amount DECIMAL(12, 2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(12, 2) DEFAULT 0,
    target_date DATE,
    icon_name TEXT DEFAULT 'savings',
    color TEXT DEFAULT '#4CAF50',
    is_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Index
CREATE INDEX IF NOT EXISTS idx_savings_goals_user ON savings_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_savings_goals_completed ON savings_goals(is_completed);

-- RLS
ALTER TABLE savings_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own savings goals" ON savings_goals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own savings goals" ON savings_goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own savings goals" ON savings_goals
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own savings goals" ON savings_goals
    FOR DELETE USING (auth.uid() = user_id);

-- 5. TABLE BUDGET_CATEGORIES (Catégories avec budget)
-- =====================================================
CREATE TABLE IF NOT EXISTS budget_categories (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    budget_limit DECIMAL(12, 2) DEFAULT 0,
    icon_name TEXT DEFAULT 'category',
    color TEXT DEFAULT '#607D8B',
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Index
CREATE INDEX IF NOT EXISTS idx_budget_categories_user ON budget_categories(user_id);

-- Contrainte unique sur le nom par utilisateur
CREATE UNIQUE INDEX IF NOT EXISTS idx_budget_categories_unique_name 
    ON budget_categories(user_id, name);

-- RLS
ALTER TABLE budget_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own budget categories" ON budget_categories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own budget categories" ON budget_categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own budget categories" ON budget_categories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own budget categories" ON budget_categories
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- FIN DU SCRIPT
-- =====================================================

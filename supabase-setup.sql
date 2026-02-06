-- =============================================
-- SUPABASE FLASHCARDS TABLE SETUP
-- Run this in Supabase SQL Editor
-- =============================================

-- Create the flashcards table
CREATE TABLE IF NOT EXISTS flashcards (
    id SERIAL PRIMARY KEY,
    unit INTEGER NOT NULL,
    topic TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('term', 'formula', 'advantages', 'theory')),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create an index for faster filtering
CREATE INDEX idx_flashcards_unit ON flashcards(unit);
CREATE INDEX idx_flashcards_topic ON flashcards(topic);
CREATE INDEX idx_flashcards_type ON flashcards(type);

-- Enable Row Level Security (RLS)
ALTER TABLE flashcards ENABLE ROW LEVEL SECURITY;

-- Create policy to allow anyone to read flashcards (public access for students)
CREATE POLICY "Allow public read access" ON flashcards
    FOR SELECT
    USING (true);

-- Create policy to allow only authenticated users to insert/update/delete
-- (for admin operations)
CREATE POLICY "Allow authenticated insert" ON flashcards
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "Allow authenticated update" ON flashcards
    FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "Allow authenticated delete" ON flashcards
    FOR DELETE
    TO authenticated
    USING (true);

-- Create a function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_flashcards_updated_at
    BEFORE UPDATE ON flashcards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

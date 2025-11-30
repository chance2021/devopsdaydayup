package com.example.bookapi.model;

public class Comment {
    private String text;

    // Default constructor
    public Comment() {
    }

    // Constructor with parameter
    public Comment(String text) {
        this.text = text;
    }

    // Getter and Setter
    public String getText() {
        return text;
    }

    public void setText(String text) {
        this.text = text;
    }
}
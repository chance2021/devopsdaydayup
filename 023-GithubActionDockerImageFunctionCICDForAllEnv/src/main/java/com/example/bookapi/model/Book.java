package com.example.bookapi.model;

import java.util.List;

public class Book {
    private String number;
    private String name;
    private List<Comment> comments;

    // Default constructor
    public Book() {
    }

    // Constructor with parameters
    public Book(String number, String name, List<Comment> comments) {
        this.number = number;
        this.name = name;
        this.comments = comments;
    }

    // Getters and Setters
    public String getNumber() {
        return number;
    }

    public void setNumber(String number) {
        this.number = number;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public List<Comment> getComments() {
        return comments;
    }

    public void setComments(List<Comment> comments) {
        this.comments = comments;
    }
}